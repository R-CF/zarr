#' Zarr Array
#'
#' @description This class implements a Zarr array. A Zarr array is stored in a
#'   node in the hierarchy of a Zarr data set. The array contains the data for
#'   an object.
#' @docType class
zarr_array <- R6::R6Class('zarr_array',
  inherit = zarr_node,
  cloneable = FALSE,
  private = list(
    # The list of codec instances with which to encode a chunk-shaped array into
    # a storable byte-stream, or decode in the reverse order.
    .codecs = list()
  ),
  public = list(
    #' @description Initialize a new array in a Zarr hierarchy. The array must
    #'   already exist in the store
    #' @param name The name of the array.
    #' @param metadata List with the metadata of the array.
    #' @param parent The parent `zarr_group` instance of this new array, can be
    #'   missing or `NULL` if the Zarr object should have just this array.
    #' @param store The [zarr_store] instance to persist data in.
    #' @return An instance of `zarr_array`.
    initialize = function(name, metadata, parent, store) {
      ab <- array_builder$new(metadata)
      if (!ab$is_valid())
        stop('Invalid metadata for an array.', call. = FALSE) # nocov

      super$initialize(name, metadata, parent, store)

      # Build a processor
      private$.codecs <- ab$codecs
    },

    #' @description Print a summary of the array to the console.
    print = function() {
      cat('<Zarr array>', private$.name, '\n')
      cat('Path     :', self$path, '\n')
      cat('Shape    :', private$.metadata[['shape']], '\n')
      invisible(self)
    }
  ),
  active = list(
    #' @field codecs The list of codecs that this array uses for encoding data
    #' (and decoding in inverse order).
    codecs = function(value) {
      if (missing(value))
        private$.codecs
    }
  )
)
