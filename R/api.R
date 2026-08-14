#' Create a Zarr store
#'
#' This function creates a Zarr v.3 instance, with a store located on the local
#' file system. The root of the Zarr store will be a group to which other groups
#' or arrays can be added.
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
  store <- if (missing(location) || !nzchar(location)) zarr_memorystore$new()
           else zarr_localstore$new(location)
  store$create_group(name = '')
  zarr$new(store)
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
#' @param protocol Character string. Override automatic protocol detection
#'   ('local', 'http', or 's3'). Needed for S3-compatible endpoints that
#'   aren't AWS and don't follow AWS's hostname conventions (MinIO, EMBASSY
#'   Cloud, Ceph RGW, etc.) - there's no reliable way to recognize these from
#'   the URL alone, you have to indicate so explicitly rather than have
#'   `open_zarr()` parse the location.
#' @param ... Additional protocol-specific parameters passed through to the
#'   underlying store constructor. For `s3://` and S3 `https://` locations,
#'   this includes `region`, `profile`, `access_key`/`secret_key`/
#'   `session_token`, `endpoint`, and `anonymous` — see [zarr_s3store]. Ignored
#'   for local and plain HTTP locations.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' africa
open_zarr <- function(location, read_only = NULL, protocol = NULL, ...) {
  proto <- protocol %||% .protocol(location)
  if (is.null(read_only))
    read_only <- proto != 'local'

  store <- switch(proto,
                  'local' = zarr_localstore$new(location, read_only),
                  'http'  = zarr_httpstore$new(location),
                  's3'    = {
                    loc <- .parse_s3_location(location)
                    zarr_s3store$new(bucket = loc$bucket, prefix = loc$prefix,
                                     region = loc$region, endpoint = loc$endpoint,
                                     read_only = read_only, ...)
                  },
                  stop('Unsupported location: ', location, call. = FALSE)
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
as_zarr <- function(x, name = NULL, location = NULL) {
  if (is.numeric(x) || is.logical(x) || is.character(x)) {
    # Build the array metadata from x
    ab <- array_builder$new()
    ab$data_type <- switch(storage.mode(x),
                           'logical'   = 'bool',
                           'integer'   = 'int32',
                           'double'    = 'float64',
                           'character' = 'string',
                           stop('Unsupported data type:', storage.mode(x), call. = FALSE))
    d <- dim(x) %||% length(x)
    ab$shape <- d
    ab$chunk_shape <- .auto_chunk(d)
    if (prod(d) > Zarr.options$min_compress)
      ab$add_codec('blosc', list(clevel = 6L))

    if (inherits(location, 'zarr_group')) {
      if (missing(name) || is.null(name))
        stop('Argument `name` must be provided', call. = FALSE)
      out <- location
      arr <- out$add_array(name, ab)
    } else {
      # Create the store and add the array to make the store valid
      store <- if (missing(location) || is.null(location) || !nzchar(location))
        zarr_memorystore$new()
      else
        zarr_localstore$new(root = location)

      if (missing(name) || is.null(name) || !nzchar(name)) {
        name <- ''
        store$create_array(name = '', metadata = ab$metadata())
      } else if (is_valid_node_name(name)) {
        store$create_group(name = '')
        store$create_array(parent = '/', name = name, metadata = ab$metadata())
      } else
        stop('Invalid name for a Zarr array: ', name, call. = FALSE)

      # Create the Zarr object and get a handle on the newly created array
      out <- zarr$new(store)
      arr <- out[[paste0('/', name)]]
    }

    # Store the data from x
    arr$write(x)

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
  ab$add_codec('blosc', list(clevel = 6L))
  ab
}

#' Get optimal chunking size for an array.
#'
#' This function will determine the optimal chunking sizes of the array
#' dimensions based on weights per dimension.
#'
#' @param dim_sizes Named integer array of dimension lengths, corresponding to
#'   the `shape` of the array.
#' @param weights Optional, numeric vector with weights per dimension.
#'   If omitted, each dimension will have a weight of 1L, i.e. no
#'   preferential chunking on any dimension.
#' @param chunk_values Optional, integer value given the maximum number of array
#'   elements per chunk. Default is 4 million, meaning that the chunk size of
#'   `float32` data is at most 16MB uncompressed.
#' @return An integer vector with chunk length per group or dimension.
#' @export
#' @examples
#' shape <- c(x = 50000L, y = 350L, time = 8192)
#'
#' # Default chunking, approaching the maximum chunk size
#' optimal_chunking(dim_sizes = shape)
#'
#' # Prioritize extractions over the "time" dimension
#' optimal_chunking(dim_sizes = shape, weights = c(1, 1, 2))
#'
#' # Prioritize extractions over the grouped "x" and "y" dimensions
#' optimal_chunking(dim_sizes = shape,
#'                  groups = list(c("x", "y"), "time"),
#'                  weights = c(1.3, 1))
optimal_chunking <- function(dim_sizes, groups, weights,
                             chunk_values = 4L * 1024L * 1024L) {
  if (missing(groups) || is.null(groups)) {
    groups <- as.list(names(dim_sizes))
    names(groups) <- names(dim_sizes)
  }
  len <- length(groups)

  if (missing(weights))
    weights <- rep(1L, len)
  if (length(weights) != len)
    stop("weights must have one entry per group (", len, "), got ", length(weights))

  covered <- unlist(groups)
  missing_dims <- setdiff(names(dim_sizes), covered)
  if (length(missing_dims) > 0)
    stop("dimensions not covered by any group: ",
         paste(missing_dims, collapse = ", "))

  # Size-1 dimensions can never be partitioned, so their weight must not
  # dilute the exponent that drives every other dimension's chunk size.
  # A group counts toward the weight budget only if it has at least one
  # dimension with size > 1.
  group_has_volume <- vapply(groups, function(g) any(dim_sizes[g] > 1L), logical(1))
  W <- sum(weights[group_has_volume])

  if (W == 0) {
    # every dimension is size 1; nothing to partition
    return(as.list(dim_sizes))
  }

  x <- chunk_values^(1 / W)

  chunk_sizes <- list()

  for (i in seq_along(groups)) {
    group <- groups[[i]]
    weight <- weights[i]

    non_trivial <- group[dim_sizes[group] > 1L]
    trivial     <- group[dim_sizes[group] == 1L]

    for (dim in trivial) chunk_sizes[[dim]] <- 1L
    if (length(non_trivial) == 0L) next

    group_size <- floor(x^weight)

    if (length(non_trivial) == 1L) {
      dim <- non_trivial[1]
      chunk_sizes[[dim]] <- min(group_size, dim_sizes[[dim]])
    } else {
      x_group <- group_size^(1 / length(non_trivial))
      for (dim in non_trivial) {
        chunk_sizes[[dim]] <- min(floor(x_group), dim_sizes[[dim]])
      }
    }
  }

  # Second pass: align chunk sizes to tile each dimension evenly,
  # avoiding a near-full chunk plus a small leftover remainder.
  .align_chunk <- function(chunk_size, dim_size) {
    if (chunk_size >= dim_size) return(dim_size)
    n_chunks <- max(1L, round(dim_size / chunk_size))
    as.integer(ceiling(dim_size / n_chunks))
  }

  for (dim in names(chunk_sizes))
    chunk_sizes[[dim]] <- .align_chunk(chunk_sizes[[dim]], dim_sizes[[dim]])

  unlist(chunk_sizes[names(dim_sizes)])
}
