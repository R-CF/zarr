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
    .store        = NULL,
    .array_shape  = NULL,  # Shape of the array
    .scalar       = FALSE, # Is the array scalar?
    .chunk_shape  = NULL,  # Shape of an individual chunk (or shard)
    .chunk_map    = NULL,  # Map of [chunk_id] instances for I/O
    .data_type    = NULL,  # Data type of the array
    .array_prefix = '',    # Prefix to the array in the store
    .cke          = list() # Settings of the chunk key encoding
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
