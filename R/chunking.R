#' Chunk management
#'
#' @description This class implements the basic ancestor for chunking the data
#'   of Zarr arrays. It provides the basic scaffolding chunk and shard access in
#'   the Zarr store and stores objects for topology operations on the chunk grid
#'   of the array.
#'
#'   Descendant classes implement specific chunking schemes. Apart from the
#'   "regular" chunking that is a required component of Zarr v.3, implemented
#'   through the `chunk_grid_regular` class, Zarr arrays that use sharding are
#'   also treated as a chunk manager, the `chunk_grid_sharded` class, even
#'   though sharding is a codec in the Zarr v.3 specification. The reason for
#'   this is that the sharding "codec" has to do the same topological operations
#'   as a regular chunk manager to map a user request for data to ranges across
#'   multiple chunks (and shards) and then apply the set of codecs that apply.
#'   These codecs for sharded data are embedded in the sharding configuration.
#'
#'   There is no point instantiating this class directly, other than in the
#'   `initialize()` method of a descendant class.
#' @docType class
#' @keywords internal
chunking <- R6::R6Class('chunking',
  inherit = zarr_extension,
  cloneable = FALSE,
  private = list(
    .store          = NULL,
    .array_shape    = NULL,   # Shape of the array
    .scalar         = FALSE,  # Is the array scalar?
    .chunk_shape    = NULL,   # Shape of an individual chunk (or shard)
    .chunk_map      = NULL,   # Map of [chunk_id] instances for I/O
    .data_type      = NULL,   # Data type of the array
    .array_prefix   = '',     # Prefix to the array in the store
    .cke            = list(), # Settings of the chunk key encoding
    .clip_supported = TRUE,   # Can resize array?

    # Parse existing chunk/shard keys into a matrix of 0-based grid indices.
    parse_chunk_keys = function(keys) {
      lead <- paste0(private$.array_prefix, private$.cke$pre)
      rel  <- substring(keys, nchar(lead) + 1L)
      do.call(rbind, lapply(strsplit(rel, private$.cke$sep, fixed = TRUE), as.integer))
    },

    # Build a store key (full-length cidx) or a directory prefix (shorter
    # cidx, for hierarchical stores) for the given grid indices.
    build_chunk_prefix = function(cidx) {
      paste0(private$.array_prefix, private$.cke$pre, paste(cidx, collapse = private$.cke$sep))
    },

    # NA the excess tail of a chunk left partly outside the new shape.
    # Overridden by chunk_grid_regular; unreached elsewhere because
    # .clip_supported guards it first.
    clip_chunk = function(cidx, new_shape, clip_dims) {
      stop('Class', class(self)[1L], 'cannot clip a partial chunk') # nocov
    }
  ),
  public = list(
    #' @description Initialize a new chunking scheme for an array. This should
    #'   only be called by descendant classes.
    #' @param class_name Character string given the name of the chunking scheme.
    #' @param array_shape Integer vector of the array dimensions. This may be
    #'   `NA` for a scalar array.
    #' @param chunk_shape Integer vector of the dimensions of each chunk (or
    #'   shard). Ignored for a scalar array.
    #' @return An instance of `chunking`.
    initialize = function(class_name, array_shape, chunk_shape) {
      super$initialize(class_name)

      if (is.na(array_shape[1L])) {
        private$.array_shape <- NULL
        private$.chunk_shape <- 1L
        private$.scalar <- TRUE
      } else {
        if (is.integer(array_shape) && all(array_shape > 0L))
          private$.array_shape <- array_shape
        else
          stop('Array shape must be defined using integer vector of positive values.', call. = FALSE) # nocov

        if (is.integer(chunk_shape) && all(chunk_shape > 0L) && length(array_shape) == length(chunk_shape))
          private$.chunk_shape <- chunk_shape
        else
          stop('Chunk shape is not valid for `array_shape`', call. = FALSE) # nocov
      }
      private$.chunk_map <- new.env(parent = emptyenv())
    },

    #' @description Physically resize the on-disk chunk grid: rename chunks
    #'   whose grid index moved, delete chunks that fell entirely outside the
    #'   new shape, and `NA` the excess tail of a chunk left partly outside a
    #'   shrinking, non-chunk-aligned high boundary. No chunk payload is
    #'   re-encoded except for that trailing clip.
    #' @param new_shape Integer vector, the array's new shape.
    #' @param shift Integer vector, whole chunks by which the origin moves
    #'   per dimension (positive = grew at the low end, negative = shrank).
    #' @param high Integer vector, the requested high-end element deltas
    #'   (used only to decide which boundary chunks need NA-clipping).
    #' @return Self, invisibly.
    resize = function(new_shape, shift, high) {
      chunk_shape  <- private$.chunk_shape
      nd           <- length(chunk_shape)
      new_last_idx <- as.integer(floor((new_shape - 1L) / chunk_shape))
      clip_dims    <- which(high < 0L & (new_shape %% chunk_shape) != 0L)

      if (length(clip_dims) && !private$.clip_supported)
        stop('Shrinking this array to a shape that is not aligned to the ',
             'chunk (shard) boundary is not supported for this chunk grid',
             call. = FALSE)

      keys <- private$.store$list_chunks(private$.array_prefix)
      if (length(keys)) {
        cidx     <- private$parse_chunk_keys(keys)
        new_cidx <- sweep(cidx, 2L, shift, `+`)
        survives <- Reduce(`&`, lapply(seq_len(nd), function(d)
          new_cidx[, d] >= 0L & new_cidx[, d] <= new_last_idx[d]))

        for (k in keys[!survives]) private$.store$erase(k)

        keep <- which(survives)
        if (length(keep)) {
          shifted_dims <- which(shift != 0L)

          if (length(shifted_dims) == 1L && private$.store$supports_prefix_rename &&
              identical(private$.cke$sep, '/')) {
            # Collapse to one rename per existing value of the single shifted
            # dimension, at whatever depth it sits in the key path. Anything
            # nested more deeply (other dimensions) rides along unrenamed,
            # for free, as part of the same directory move.
            d <- shifted_dims
            prefixes <- unique(cidx[keep, seq_len(d), drop = FALSE])
            ord <- order(prefixes[, d] * shift[d], decreasing = TRUE)
            for (r in ord) {
              old_row <- prefixes[r, ]
              new_row <- old_row
              new_row[d] <- old_row[d] + shift[d]
              old_path <- private$build_chunk_prefix(old_row)
              new_path <- private$build_chunk_prefix(new_row)
              if (old_path != new_path) private$.store$rename_prefix(old_path, new_path)
            }
          } else if (length(shifted_dims)) {
            # General fallback: safe for any combination of simultaneously
            # shifted dimensions, or stores/encodings without a hierarchical
            # rename. Streams one chunk at a time in an order guaranteed to
            # never overwrite a chunk before it has been read: descending by
            # dot(old_cidx, shift), which for a single shifted dimension
            # reduces to "high index first when growing, low index first
            # when shrinking".
            score <- as.vector(cidx[keep, , drop = FALSE] %*% shift)
            for (i in keep[order(-score)]) {
              new_key <- private$build_chunk_prefix(new_cidx[i, ])
              if (keys[i] != new_key) private$.store$rename(keys[i], new_key)
            }
          }

          if (length(clip_dims)) {
            on_boundary <- Reduce(`|`, lapply(clip_dims, function(d)
              new_cidx[keep, d] == new_last_idx[d]))
            for (i in keep[on_boundary])
              private$clip_chunk(new_cidx[i, ], new_shape, clip_dims)
          }
        }
      }

      private$.array_shape <- new_shape
      private$.chunk_map   <- new.env(parent = emptyenv())
      invisible(self)
    }
  ),
  active = list(
    #' @field chunk_shape (read-only) The dimensions of each chunk in the chunk
    #' grid of the associated array.
    chunk_shape = function(value) {
      if (missing(value))
        private$.chunk_shape
    },

    #' @field chunk_encoding Set or retrieve the chunk key encoding to be used
    #'   for creating store keys for chunks.
    chunk_encoding = function(value) {
      if (missing(value))
        private$.cke
      else
        private$.cke <- value
    },

    #' @field data_type The data type of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    data_type = function(value) {
      if (missing(value))
        private$.data_type
      else if (inherits(value, 'zarr_data_type'))
        private$.data_type <- value
      else
        stop('Must set a valid data type.', call. = FALSE) # nocov
    },

    #' @field store The store of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    store = function(value) {
      if (missing(value))
        private$.store
      else if (inherits(value, 'zarr_store'))
        private$.store <- value
      else
        stop('Bad assignment of store.', call. = FALSE) # nocov
    },

    #' @field array_prefix The prefix of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    array_prefix = function(value) {
      if (missing(value))
        private$.array_prefix
      else
        private$.array_prefix <- value
    }
  )
)
