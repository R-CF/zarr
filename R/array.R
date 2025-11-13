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
    # The data type of the array, a zarr_data_type instance
    .data_type = NULL,

    # An instance of `chunk_grid_regular` to manage data chunking and I/O.
    .chunking = NULL,

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
      private$.data_type <- ab$data_type
      private$.chunking <- ab$chunk_shape
      private$.chunking$data_type <- private$.data_type
      private$.chunking$store <- store
      private$.chunking$array_prefix <- self$prefix
      private$.chunking$codecs <- ab$codecs
    },

    #' @description Print a summary of the array to the console.
    print = function() {
      cat('<Zarr array>', private$.name, '\n')
      cat('Path      :', self$path, '\n')
      cat('Data type :', private$.data_type$data_type, '\n')
      cat('Shape     :', private$.metadata$shape, '\n')
      cat('Chunking  :', private$.metadata$chunk_grid$configuration$chunk_shape, '\n')
      self$print_attributes()
      invisible(self)
    },

    #' @description Prints the hierarchy of the groups and arrays to the
    #'   console. Usually called from the Zarr object or its root group to
    #'   display the full group hierarchy.
    #' @param idx,total Arguments to control indentation.
    hierarchy = function(idx, total) {
      if (!nzchar(private$.name))
        '\u2317 (root array)\n'
      else {
        knot <- if (idx == total) '\u2514 ' else '\u251C '
        paste0(knot, '\u2317 ', private$.name, '\n')
      }
    },

    #' @description Read some or all of the array data for the array.
    #' @param selection A list as long as the array has dimensions where each
    #'   element is a range of indices along the dimension to write. If missing,
    #'   the entire array will be read.
    #' @return A vector, matrix or array of data.
    read = function(selection) {
      array_shape <- private$.metadata$shape
      if (missing(selection))
        selection <- lapply(array_shape, function(d) c(1L, d))
      if (length(selection) == length(array_shape)) {
        # `data` is a hyperslab of any dimensions
        start <- sapply(selection, min)
        stop  <- sapply(selection, max)
        if (any(start < 1L | start > array_shape | stop > array_shape))
          stop('Array selection indices are out of bounds.', call. = FALSE) # nocov
        private$.chunking$read(start, stop)
      } else
        stop('`selection` list must have the same length as the shape of the array.', call. = FALSE) # nocov
    },

    #' @description Write data for the array. The data will be chunked, encoded
    #'   and persisted in the store that the array is using.
    #' @param data An R vector, matrix or array with the data to write. The data
    #'   in the R object has to agree with the data type of the array.
    #' @param selection A list as long as the array has dimensions where each
    #'   element is a range of indices along the dimension to write. If missing,
    #'   the entire `data` object will be written.
    #' @return Self, invisibly.
    write = function(data, selection) {
      if (storage.mode(data) != private$.data_type$Rtype)
        stop('Data is of a different type than the array.', call. = FALSE) # nocov

      array_shape <- private$.metadata$shape
      if (missing(selection))
        selection <- lapply(dim(data) %||% length(data), function(d) c(1L, d))
      nsel <- length(selection)
      if (nsel == length(array_shape)) {
        start <- sapply(selection, min)
        stop  <- sapply(selection, max)
        sdim  <- stop - start + 1L

        ddim <- dim(data) %||% length(data)
        ndata <- length(ddim)
        if (nsel < ndata)
          stop("Data has higher rank than the selection indices.", call. = FALSE) # nocov
        if (!(nsel == ndata && all(ddim == sdim))) {
          # Broadcast `data` to selection dimensions
          ddim <- c(rep(1L, nsel - ndata), ddim)
          if (any(!(ddim == sdim | ddim == 1L)))
            stop("Cannot broadcast data to selection dimensions", call. = FALSE) # nocov
          data <- array(data, dim = ddim)
          if ((proddim <- prod(sdim)) != prod(ddim))
            data <- array(rep(data, each = proddim), dim = sdim)
        }
        private$.chunking$write(data, start, stop)
      } else
        stop('`selection` list must have the same length as the shape of the array.', call. = FALSE) # nocov
      invisible(self)
    }
  ),
  active = list(
    #' @field data_type (read-only) Retrieve the data type of the array.
    data_type = function(value) {
      if (missing(value))
        private$.data_type
    },

    #' @field shape (read-only) Retrieve the shape of the array, an integer
    #'   vector.
    shape = function(value) {
      if (missing(value))
        private$.metadata$shape
    },

    #' @field chunking (read-only) The chunking engine for this array.
    chunking = function(value) {
      if (missing(value))
        private$.chunking
    },

    #' @field codecs The list of codecs that this array uses for encoding data
    #' (and decoding in inverse order).
    codecs = function(value) {
      if (missing(value))
        private$.chunking$codecs
    }
  )
)

# --- S3 functions ---
#' Compact display of a Zarr array
#' @param object A `zarr_array` instance.
#' @param ... Ignored.
#' @export
str.zarr_array <- function(object, ...) {
  cat('Zarr array: [', object$data_type$data_type, '] shape [',
      paste(object$shape, collapse = ', '), '] chunk [',
      paste(object$chunking$chunk_shape, collapse = ', '), ']', sep = '')
}

#' Extract or replace parts of a Zarr array
#'
#' These operators can be used to extract or replace data from an array by
#' indices. Normal R array selection rules apply. The only limitation is that
#' the indices have to be consecutive.
#'
#' @param x A `zarr_array` object of which to extract or replace the data.
#' @param ... Indices specifying elements to extract or replace. Indices are
#'   numeric, empty (missing) or `NULL`. Numeric values are coerced to integer
#'   or whole numbers. The number of indices has to agree with the
#'   dimensionality of the array.
#' @param drop If `TRUE` (the default), degenerate dimensions are dropped, if
#'   `FALSE` they are retained in the result.
#' @return When extracting data, a vector, matrix or array, having dimensions as
#'   specified in the indices. When replacing part of the Zarr array, returns
#'   `x` invisibly.
#' @name array-indexing
#' @export
#' @docType methods
#' @examples
#' x <- array(1:100, c(10, 10))
#' z <- as_zarr(x)
#' arr <- z[["/"]]
#' arr[3:5, 7:9]
`[.zarr_array` <- function(x, ..., drop = TRUE) {
  indices <- as.list(substitute(list(...)))[-1L]
  selection <- .indices2selection(indices, x$shape)
  data <- x$read(selection)
  if (drop) drop(data) else data
}

# --- Internal helper functions ---
.indices2selection <- function(indices, shape) {
  nd <- length(shape)
  if (length(indices) != nd && !(length(indices) == 1L && is.symbol(indices[[1L]])))
    stop('Invalid number of selection indices for the array.', call. = FALSE) # nocov
  selection <- vector("list", nd)

  for (d in seq_len(nd)) {
    if (d > length(indices) || is.symbol(indices[[d]]) || is.null(indices[[d]])) {
      # Missing index
      selection[[d]] <- c(1L, shape[d])
    } else {
      sel <- eval(indices[[d]], parent.frame())
      if (is.logical(sel))
        sel <- which(sel)
      else if (any(sel < 0L))
        sel <- setdiff(seq_len(shape[d]), abs(sel))
      selection[[d]] <- range(sort(unique(sel)))
    }
  }
  selection
}
