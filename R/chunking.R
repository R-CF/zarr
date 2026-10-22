#' Chunk management
#'
#' @description This class implements the basic ancestor for chunking the data
#'   of Zarr arrays. It provides the mechanism for chunk access in the Zarr
#'   store that is independent of the geometry of the chunk grid: addressing
#'   chunks by their grid index through the chunk key encoding, caching chunk
#'   I/O objects, raw chunk access and relocating chunks in the store.
#'
#'   The geometry of the chunk grid - how the array is partitioned into chunks
#'   along each dimension - is the responsibility of descendant classes. The
#'   "regular" chunk grid that is a required component of Zarr v.3 is
#'   implemented by the `chunk_grid_regular` class. Zarr arrays that use
#'   sharding are managed by the `chunk_grid_sharded` class, a descendant of
#'   `chunk_grid_regular` because the sharding codec requires a regular grid of
#'   shards. Sharding is treated as a chunking scheme rather than as a codec
#'   because it has to do the same topological operations as a regular chunk
#'   manager to map a user request for data to ranges across multiple chunks
#'   (and shards) and then apply the set of codecs that apply. These codecs for
#'   sharded data are embedded in the sharding configuration.
#'
#'   A descendant class must set the private field `.grid` and implement the
#'   private method `max_chunk_length()` and the public methods `resize()`,
#'   `read()` and, if supported, `write()`.
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
    .array_shape    = NULL,       # Shape of the array
    .scalar         = FALSE,      # Is the array scalar?
    .grid           = integer(0), # Number of chunks along each dimension, set by descendant class
    .chunk_map      = NULL,       # Map of [chunk_id] instances for I/O
    .chunk_touch    = NULL,       # Parallel map: chunk_key -> last-touched tick
    .tick           = 0L,         # Monotonically increasing touch counter
    .chunk_bytes    = 0L,         # Bytes per resident chunk buffer (0 = not yet known)
    .data_type      = NULL,       # Data type of the array
    .array_prefix   = '',         # Prefix to the array in the store
    .cke            = list(),     # Settings of the chunk key encoding

    # Number of elements in the largest chunk of the grid, used to size the
    # chunk cache.
    max_chunk_length = function() {
      stop('This method must be implemented by descendant classes', call. = FALSE) # nocov
    },

    # The chunks (or shards) of the array that are present in the store, as a
    # list with their full store `keys` and the matrix `cidx` of their 0-based
    # grid indices. The store may list keys under the array prefix that are
    # not chunks, such as the metadata document of a root array; only keys
    # that the chunk key encoding produces for a grid of this rank are kept.
    stored_chunks = function() {
      nd   <- length(private$.grid)
      sep  <- private$.cke$sep
      lead <- paste0(private$.array_prefix, private$.cke$pre)
      keys <- private$.store$list_chunks(private$.array_prefix)
      keys <- keys[startsWith(keys, lead)]
      rel  <- substring(keys, nchar(lead) + 1L)
      parts <- strsplit(rel, sep, fixed = TRUE)
      ok <- !endsWith(rel, sep) &
            vapply(parts, function(p) length(p) == nd && all(grepl('^[0-9]+$', p)), logical(1L))
      list(keys = keys[ok],
           cidx = matrix(as.integer(unlist(parts[ok])), ncol = nd, byrow = TRUE))
    },

    # Build a store key (full-length cidx) or a directory prefix (shorter
    # cidx, for hierarchical stores) for the given grid indices.
    build_chunk_prefix = function(cidx) {
      paste0(private$.array_prefix, private$.cke$pre, paste(cidx, collapse = private$.cke$sep))
    },

    # Record or refresh a chunk's position in the LRU order. Call on every
    # cache hit and on every insert.
    touch_chunk = function(key) {
      private$.tick <- private$.tick + 1L
      assign(key, private$.tick, envir = private$.chunk_touch)
    },

    # Ensure there is room for one more resident chunk before inserting a new
    # one. Evicts the least-recently-touched entries, flushing each first if
    # it has unpersisted changes. No-op until .chunk_bytes is known.
    evict_for_capacity = function() {
      if (private$.chunk_bytes <= 0L) return(invisible(NULL))
      cap <- max(1L, Zarr.options$chunk_cache_bytes %/% private$.chunk_bytes)
      while (length(private$.chunk_touch) >= cap) {
        ticks  <- unlist(as.list(private$.chunk_touch, all.names = TRUE))
        oldest <- names(ticks)[which.min(ticks)]
        io <- private$.chunk_map[[oldest]]
        if (!is.null(io)) io$flush()
        rm(list = oldest, envir = private$.chunk_map)
        rm(list = oldest, envir = private$.chunk_touch)
      }
    },

    # Persist all pending edits and empty the chunk cache.
    drop_cache = function() {
      for (key in ls(private$.chunk_map, all.names = TRUE))
        private$.chunk_map[[key]]$flush()
      private$.chunk_map   <- new.env(parent = emptyenv())
      private$.chunk_touch <- new.env(parent = emptyenv())
    },

    # Move the chunks in the store by `shift` grid positions per dimension
    # (positive = towards higher indices) and erase chunks that end up outside
    # a grid of `new_grid` chunks. Chunk payload is never touched. This applies
    # to any chunk grid whose chunks are addressed by integer grid indices,
    # regardless of the extent of individual chunks. The chunk cache is
    # flushed and emptied first because cached chunks are keyed by their
    # pre-move position. Returns the matrix of new grid indices of the chunks
    # remaining in the store.
    relocate_chunks = function(shift, new_grid) {
      nd <- length(new_grid)
      private$drop_cache()

      stored <- private$stored_chunks()
      keys   <- stored$keys
      if (!length(keys)) return(matrix(0L, 0L, nd))

      cidx     <- stored$cidx
      new_cidx <- sweep(cidx, 2L, shift, `+`)
      survives <- Reduce(`&`, lapply(seq_len(nd), function(d)
        new_cidx[, d] >= 0L & new_cidx[, d] < new_grid[d]))

      for (k in keys[!survives]) private$.store$erase(k)

      keep <- which(survives)
      shifted_dims <- which(shift != 0L)
      if (length(keep) && length(shifted_dims)) {
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
        } else {
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
      }
      new_cidx[keep, , drop = FALSE]
    }
  ),
  public = list(
    #' @description Initialize a new chunking scheme for an array. This should
    #'   only be called by descendant classes, which must also set the grid of
    #'   chunks of a non-scalar array.
    #' @param class_name Character string given the name of the chunking scheme.
    #' @param array_shape Integer vector of the array dimensions. This may be
    #'   `NA` for a scalar array.
    #' @return An instance of `chunking`.
    initialize = function(class_name, array_shape) {
      super$initialize(class_name)

      if (is.na(array_shape[1L])) {
        private$.array_shape <- NULL
        private$.grid <- integer(0)
        private$.scalar <- TRUE
      } else if (is.integer(array_shape) && all(array_shape > 0L))
        private$.array_shape <- array_shape
      else
        stop('Array shape must be defined using integer vector of positive values', call. = FALSE) # nocov

      private$.chunk_map <- new.env(parent = emptyenv())
      private$.chunk_touch <- new.env(parent = emptyenv())
    },

    #' @description Resize the array by growing or shrinking any combination
    #'   of dimensions at either end, updating the chunks in the store
    #'   accordingly. How a requested change maps onto the chunk grid is
    #'   determined by the descendant class.
    #' @param low,high Integer vectors, one element per array dimension, with
    #'   the requested change in extent at the low and high end of each
    #'   dimension. Positive grows that end, negative shrinks it.
    #' @return Self, invisibly.
    resize = function(low, high) {
      stop('This method must be implemented by descendant classes', call. = FALSE) # nocov
    },

    #' @description Move the chunks in the store to the grid of an array whose
    #'   rank is one higher, by inserting a new dimension that holds exactly
    #'   one chunk. A scalar array has its single chunk moved to the first
    #'   chunk of a rank-1 grid. Chunk payload is never touched. The chunking
    #'   scheme itself is not updated: the caller must create a new chunking
    #'   scheme for the promoted array.
    #' @param dimension Integer, the 1-based position of the new dimension in
    #'   the grid of the promoted array.
    #' @return Self, invisibly.
    insert_dimension = function(dimension) {
      private$drop_cache()
      if (private$.scalar) {
        scalar_key <- paste0(private$.array_prefix, private$.cke$scalar)
        if (private$.store$exists(scalar_key))
          private$.store$rename(scalar_key, private$build_chunk_prefix(0L))
      } else {
        stored <- private$stored_chunks()
        for (i in seq_along(stored$keys)) {
          new_key <- private$build_chunk_prefix(append(stored$cidx[i, ], 0L, after = dimension - 1L))
          if (stored$keys[i] != new_key) private$.store$rename(stored$keys[i], new_key)
        }
      }
      invisible(self)
    },

    #' @description Generate the keys of all chunks in the chunk grid, or of
    #'   all shards for a sharded array. Keys are derived from the grid and the
    #'   chunk key encoding, not by listing the store, so this works for stores
    #'   that cannot list their keys. Chunks need not exist in the store.
    #' @return A character vector of chunk keys, relative to the array prefix.
    chunk_keys = function() {
      if (private$.scalar) return(private$.cke$scalar)
      grid <- as.matrix(expand.grid(lapply(private$.grid, function(k) seq_len(k) - 1L)))
      paste0(private$.cke$pre, apply(grid, 1L, paste, collapse = private$.cke$sep))
    },

    #' @description Read the bytes of a chunk (or shard) as they are held in
    #'   the store, without decoding. Any pending edits to the chunk are
    #'   flushed to the store first.
    #' @param key Chunk key relative to the array prefix, as produced by
    #'   `chunk_keys()`.
    #' @return A raw vector, or `NULL` if the chunk is not present in the
    #'   store.
    read_raw = function(key) {
      key <- paste0(private$.array_prefix, key)
      io <- private$.chunk_map[[key]]
      if (!is.null(io)) io$flush()
      private$.store$get(key)
    },

    #' @description Write the bytes of a chunk (or shard) to the store, without
    #'   encoding. Any cached copy of the chunk is dropped. The caller is
    #'   responsible for `value` being consistent with the codecs of the array.
    #' @param key Chunk key relative to the array prefix, as produced by
    #'   `chunk_keys()`.
    #' @param value A raw vector with the encoded chunk.
    #' @return Self, invisibly.
    write_raw = function(key, value) {
      key <- paste0(private$.array_prefix, key)
      io <- private$.chunk_map[[key]]
      if (!is.null(io)) {
        # Flush, so the finalizer of the dropped buffer can't overwrite `value`
        io$flush()
        rm(list = key, envir = private$.chunk_map)
        rm(list = key, envir = private$.chunk_touch)
      }
      private$.store$set(key, value)
      invisible(self)
    },

    #' @description Persist the data in all chunks with pending edits to the
    #'   store. This base implementation is a no-op for chunking schemes that
    #'   do not buffer writes.
    #' @return Self, invisibly.
    flush = function() invisible(self)
  ),
  active = list(
    #' @field array_shape (read-only) The shape of the array, `NULL` for a
    #'   scalar array.
    array_shape = function(value) {
      if (missing(value))
        private$.array_shape
    },

    #' @field grid (read-only) The number of chunks along each dimension of the
    #'   array. This is an empty integer vector for a scalar array.
    grid = function(value) {
      if (missing(value))
        private$.grid
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
      else if (inherits(value, 'zarr_data_type')) {
        private$.data_type <- value
        private$.chunk_bytes <- private$max_chunk_length() * value$size
      } else
        stop('Must set a valid data type', call. = FALSE) # nocov
    },

    #' @field store The store of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    store = function(value) {
      if (missing(value))
        private$.store
      else if (inherits(value, 'zarr_store'))
        private$.store <- value
      else
        stop('Bad assignment of store', call. = FALSE) # nocov
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
