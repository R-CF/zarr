#' Create a Zarr store
#'
#' This function creates a Zarr v.3 instance. The root of the Zarr store will be
#' a group to which other groups or arrays can be added.
#' @param location Optional. Character string that indicates a location on a
#'   file system where the data in the Zarr object will be persisted in a Zarr
#'   store in a directory. The character string may contain UTF-8 characters
#'   and/or use a file URI format. The Zarr specification recommends that the
#'   location use the ".zarr" extension to identify the location as a Zarr
#'   store. If missing, a Zarr store will be created in memory.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- tempfile(fileext = ".zarr")
#' my_zarr_object <- create_zarr(fn)
#' my_zarr_object$store$root
#' unlink(fn)
create_zarr <- function(location) {
  z <- zarr$new(location)
  zarr_group$new(name = '', parent = z)
  z
}

#' Open a Zarr store
#'
#' This function opens a Zarr object, connected to a store located on the local
#' file system or on a remote server using the HTTP or S3 protocol. The Zarr
#' object can be either v.2 or v.3.
#' @param location Character string that indicates a location on a file system
#'   or a HTTP or S3 server where the Zarr store is to be found. The character
#'   string may contain UTF-8 characters and/or use a file URI format.
#' @param read_only Optional. Logical that indicates if the store is to be
#'   opened in read-only mode. Default is ` NULL`, which implies `FALSE` for a
#'   local file system store, `TRUE` otherwise.
#' @param protocol Optional, character string. Override automatic protocol
#'   detection ('local', 'http', or 's3'). Needed for S3-compatible endpoints
#'   that aren't AWS and don't follow AWS's hostname conventions (MinIO, EMBASSY
#'   Cloud, Ceph RGW, etc.) - there's no reliable way to recognize these from
#'   the URL alone, you have to indicate so explicitly rather than have
#'   `open_zarr()` parse the location.
#' @param ... Additional protocol-specific parameters passed through to the
#'   underlying store constructor. For `s3://` and S3 `https://` locations, this
#'   includes `region`, `profile`, `access_key`/`secret_key`/ `session_token`,
#'   `endpoint`, and `anonymous` — see [zarr_s3store]. Ignored for local and
#'   plain HTTP locations.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' africa
open_zarr <- function(location, read_only = NULL, protocol = NULL, ...) {
  if (is.character(location) && length(location) == 1L &&
      (protocol %||% .protocol(location)) == 'local' &&
      !dir.exists(uri_to_path(location)))
    stop('No Zarr store at location: ', location, call. = FALSE)

  zarr$new(location, read_only, protocol, ...)
}

#' Convert an R object into a Zarr array
#'
#' This function creates a Zarr object from an R vector, matrix or array.
#' Default settings will be taken from the R object (data type, shape). Data is
#' chunked into chunks of length 100 (or less if the array is smaller) and
#' compressed.
#' @param x The R object to convert. Must be a vector, matrix or array of a
#'   numeric, character or logical type.
#' @param name Optional. The name of the Zarr array to be created. If omitted,
#'   an array will be created at the root of the Zarr store.
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
#'   returned. Otherwise, the `zarr` object that is newly created and which
#'   contains the Zarr array, or an error if the `zarr` object could not be
#'   created.
#' @docType methods
#' @export
#' @examples
#' x <- array(1:400, c(5, 20, 4))
#' z <- as_zarr(x)
#' z
as_zarr <- function(x, name = '', location = NULL) {
  dimnames(x) <- NULL # Avoid dimnames on cached data

  # Build the array metadata from x
  ab <- array_builder$new()
  ab$data_type_from_storage.mode <- storage.mode(x)
  d <- dim(x) %||% length(x)
  ab$shape <- d
  ab$chunk_shape <- auto_chunk(d)
  if (prod(d) > Zarr.options$min_compress)
    ab$add_codec('blosc', list(clevel = 6L))

  # New array in existing store
  if (inherits(location, 'zarr_group')) {
    arr <- location$add_array(name, ab)
    arr$write(x)
    return(location)
  }

  out <- zarr$new(location)
  if (!nzchar(name)) {
    zarr_array$new(name = '', metadata = ab$metadata(), parent = out)
    out$root$write(x)
  } else {
    zarr_group$new(name = '', parent = out)
    arr <- zarr_array$new(name = name, metadata = ab$metadata(), parent = out$root)
    arr$write(x)
  }
  out
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
  ab$add_codec('blosc', list(clevel = 6L))
  ab
}

#' Get optimal chunking size for an array.
#'
#' This function will determine the optimal chunking sizes of the array
#' dimensions based on weights per dimension.
#'
#' @param dim_sizes Integer array of dimension lengths, corresponding to the
#'   `shape` of the array.
#' @param weights Optional, numeric vector with weights per dimension, in the
#'   same order as `dim_sizes`. If omitted, each dimension will have a weight of
#'   1L, i.e. no preferential chunking on any dimension.
#' @param chunk_values Optional, integer value given the maximum number of array
#'   elements per chunk. Default is 4 million, meaning that the chunk size of
#'   `float32` data is at most 16MB uncompressed.
#' @return An integer vector with chunk length per dimension in the same order
#'   as argument `dim_sizes`.
#' @export
#' @examples
#' shape <- c(x = 50000L, y = 350L, time = 8192)
#'
#' # Default chunking, approaching the maximum chunk size
#' optimal_chunking(dim_sizes = shape)
#'
#' # Prioritize extractions over the "time" dimension
#' optimal_chunking(dim_sizes = shape, weights = c(1, 1, 2))
optimal_chunking <- function(dim_sizes, weights, chunk_values = 4L * 1024L * 1024L) {
  len <- length(dim_sizes)
  if (missing(weights))
    weights <- rep(1, len)
  else if (length(weights) != len)
    stop('Length of `dim_sizes` and `weights` arguments must be the same', call. = FALSE)
  if (any(weights <= 0))
    stop('Weights must be positive', call. = FALSE)

  W <- sum(weights[dim_sizes > 1L])
  if (W == 0) # Every dimension is size 1; nothing to partition
    return(as.integer(dim_sizes))

  x <- chunk_values^(1 / W)

  chunk_sizes <- vector("numeric", len)
  for (d in seq_len(len))
    chunk_sizes[d] <- if (dim_sizes[d] == 1L) 1
                      else min(floor(x^weights[d]), dim_sizes[d])

  # Second pass: align chunk sizes to tile each dimension evenly,
  # avoiding a near-full chunk plus a small leftover remainder.
  for (d in seq_len(len))
    chunk_sizes[d] <-
      if (chunk_sizes[d] >= dim_sizes[d]) dim_sizes[d]
      else ceiling(dim_sizes[d] / max(1, round(dim_sizes[d] / chunk_sizes[d])))

  as.integer(chunk_sizes)
}
