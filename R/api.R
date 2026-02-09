#' Create a Zarr store
#'
#' This function creates a Zarr v.3 instance, with a store located on the local
#' file system. The root of the Zarr store will be a group to which other groups
#' or arrays can be added.
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
#' This function opens a Zarr object, connected to a store located on the local
#' file system or on a remote server using the HTTP protocol. The Zarr object
#' can be either v.2 or v.3.
#' @param location Character string that indicates a location on a file system
#'   or a HTTP server where the Zarr store is to be found. The character string
#'   may contain UTF-8 characters and/or use a file URI format.
#' @param read_only Optional. Logical that indicates if the store is to be
#'   opened in read-only mode. Default is `FALSE` for a local file system store,
#'   `TRUE` otherwise.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' africa
open_zarr <- function(location, read_only = FALSE) {
  store <- switch(.protocol(location),
                  'local' = zarr_localstore$new(location, read_only),
                  'http'  = zarr_httpstore$new(location)
                 )
  zarr$new(store)
}

#' Convert an R object into a Zarr array
#'
#' This function creates a Zarr object from an R vector, matrix or array.
#' Default settings will be taken from the R object (data type, shape). Data is
#' chunked into chunks of length 100 (or less if the array is smaller) and
#' compressed.
#' @param x The R object to convert. Must be a vector, matrix or array of a
#'   numeric or logical type.
#' @param name Optional. The name of the Zarr array to be created.
#' @param location Optional. If supplied, either an existing [zarr_group] in a
#'   Zarr object, or a character string giving the location on a local file
#'   system where to persist the data. If the argument is a `zarr_group`,
#'   argument `name` must be provided. If the argument gives the location for a
#'   new Zarr store then the location must be writable by the calling code. As
#'   per the Zarr specification, it is recommended to use a location that ends
#'   in ".zarr" when providing a location for a new store. If argument `name` is
#'   given then the Zarr array will be created in the root of the Zarr store
#'   with that name. If the `name` argument is not given, a single-array Zarr
#'   store will be created. If the `location` argument is not given, a Zarr
#'   object is created in memory.
#' @return If the `location` argument is a `zarr_group`, the new Zarr array is
#'   returned. Otherwise, the Zarr object that is newly created and which
#'   contains the Zarr array, or an error if the Zarr object could not be
#'   created.
#' @docType methods
#' @export
#' @examples
#' x <- array(1:400, c(5, 20, 4))
#' z <- as_zarr(x)
#' z
as_zarr <- function(x, name = NULL, location = NULL) {
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
    ab$chunk_shape <- pmin.int(d, Zarr.options$chunk_length)
    ab$add_codec('blosc', list(level = 6L))

    if (inherits(location, 'zarr_group')) {
      if (missing(name) || is.null(name))
        stop('Argument `name` must be privided.', call. = FALSE)
      out <- location
      arr <- out$add_array(name, ab)
    } else {
      # Create the store and add the array to make the store valid
      store <- if (missing(location) || !nzchar(location))
        zarr_memorystore$new()
      else
        zarr_localstore$new(root = location)

      if (missing(name) || is.null(name) || !nzchar(name))
        store$create_array(name = '', metadata = ab$metadata())
      else if (.is_valid_node_name(name)) {
        store$create_group(name = '')
        store$create_array(parent = '/', name = name, metadata = ab$metadata())
      } else
        stop('Invalid name for a Zarr array: ', name, call. = FALSE)

      # Create the Zarr object and get a handle on the newly created array
      out <- zarr$new(store)
      arr <- out[[paste0('/', name)]]
    }

    # Store the data from x
    selection <- lapply(d, function(x) c(1L, x))
    arr$write(x, selection)

    if (inherits(location, 'zarr_group'))
      arr
    else
      out
  }
}

#' Define the properties of a new Zarr array.
#'
#' With this function you can create a skeleton Zarr array from some  key
#' properties and a number of derived properties. Compression of the data is set
#' to a default algorithm and level. This function returns an [array_builder]
#' instance with which you can create directly the Zarr array, or set further
#' properties before creating the array.
#' @param data_type The data type of the Zarr array.
#' @param shape An integer vector giving the length along each dimension of the
#' array.
#' @return A `array_builder` instance with which a Zarr array can be created.
#' @docType methods
#' @export
#' @examples
#' x <- array(1:120, c(3, 8, 5))
#' def <- define_array("int32", dim(x))
#' def$chunk_shape <- c(4, 4, 4)
#' z <- create_zarr() # Creates a Zarr object in memory
#' arr <- z$add_array("/", "my_array", def)
#' arr$write(x)
#' arr
define_array <- function(data_type, shape) {
  ab <- array_builder$new()
  ab$data_type <- data_type
  ab$shape <- as.integer(shape)
  ab$add_codec('blosc', list(level = 6L))
  ab
}
