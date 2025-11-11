#' Create a Zarr store
#'
#' This function creates a Zarr instance, with a store located on the local file
#' system. The root of the Zarr store will be a group to which other groups or
#' arrays can be added.
#' @param location Character string that indicates a location on a file system
#'   where the data in the Zarr object will be persisted in a Zarr store in a
#'   directory. The character string may contain UTF-8 characters and/or use a
#'   file URI format. The Zarr specification recommends that the location use
#'   the ".zarr" extension to identify the location as a Zarr store.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- tempfile(fileext = ".zarr")
#' my_zarr_object <- create_zarr(fn)
#' my_zarr_object$store$root
#' unlink(fn)
create_zarr <- function(location) {
  store <- if (missing(location) || !nzchar(location)) zarr_memorystore$new()
           else zarr_localstore$new(location)
  store$create_group(name = '')
  zarr$new(store)
}

#' Open a Zarr store
#'
#' This function opens a Zarr instance, connected to a store located on the
#' local file system.
#' @param location Character string that indicates a location on a file system
#'   where the Zarr store is to be found. The character string may contain UTF-8
#'   characters and/or use a file URI format.
#' @param read_only Optional. Logical that indicates if the store is to be
#' opened in read-only mode. Default is `FALSE`.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- tempfile(fileext = ".zarr")
#' create_zarr(fn)
#' my_zarr_object <- open_zarr(fn)
#' my_zarr_object$store$root
#' unlink(fn)
open_zarr <- function(location, read_only = FALSE) {
  store <- zarr_localstore$new(location, read_only)
  zarr$new(store)
}

#' Convert an R object into a Zarr object.
#'
#' This function creates a Zarr object from an R vector, matrix or array. The
#' Zarr object will be a single Zarr array, with default settings derived from
#' the R object (data type, shape). Data is chunked into chunks of length 100
#' (or less is the array is smaller) and compressed.
#' @param x The R object to convert into a Zarr object. Must be a vector, matrix
#'   or array of a numeric or logical type.
#' @param store Optional. A location on a local file system where to persist the
#'   data. The location must be writable by the calling code. As per the Zarr
#'   specification, it is recommended to use a name that ends in ".zarr". If the
#'   `store` argument is not given, a Zarr object is created in memory.
#' @return The Zarr object, or an error if the Zarr object could not be created.
#' @export
as_zarr <- function(x, store = NULL) {
  if (is.numeric(x) || is.logical(x)) {
    # Build the array metadata from x
    ab <- array_builder$new()
    ab$data_type <- switch(storage.mode(x),
                           'logical' = 'bool',
                           'integer' = 'int32',
                           'double'  = 'float64',
                           stop('Unsupported data type:', storage.mode(x), call. = FALSE))
    d <- dim(x) %||% length(x)
    ab$shape <- d
    ab$chunk_shape <- pmin.int(d, 100L)
    ab$add_codec('gzip', list(level = 6L))

    # Create the store and add the array to make the store valid
    store <- if (missing(store) || !nzchar(store))
      zarr_memorystore$new()
    else
      zarr_localstore$new(root = store)
    store$create_array(name = '', metadata = ab$metadata())

    # Create the Zarr object and get a handle on the newly created array
    z <- zarr$new(store)
    arr <- z[['/']]

    # Store the data from x
    selection <- lapply(d, function(x) c(1L, x))
    arr$write(x, selection)

    z
  }
}
