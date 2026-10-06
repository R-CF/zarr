#' Zarr package options
#'
#' Use this function to read or modify package options.
#'
#' @param key Character. A key whose value to retrieve or modify. If missing,
#'   all options are returned.
#' @param value Optional. The new value for the option.
#' @return Nothing if argument `value` is provided. The value of argument `key`
#'   if it is provided, or a `list` with all options otherwise.
#' @export
#' @examples
#' zarr_options()
zarr_options <- function(key, value) {
  if (missing(key))
    as.list(Zarr.options)
  else if (missing(value))
    Zarr.options[[key]]
  else {
    switch(key,
           'chunk_length'      = if (is.numeric(value)) Zarr.options$chunk_length <- as.integer(value[1L]),
           'chunk_cache_bytes' = if (is.numeric(value)) Zarr.options$chunk_cache_bytes <- as.numeric(value[1L]),
           'min_compress'      = if (is.numeric(value)) Zarr.options$min_compress <- as.integer(value[1L]),
           'eps'               = if (is.numeric(value)) Zarr.options$eps <- value[1L]
    )
  }
}

#' Check if the name of a node is valid in Zarr
#'
#' @description
#' From the Zarr specification, the following constraints apply to node names:
#'
#' * must not be the empty string (""), except for the root node
#' * must not be a string composed only of period characters, e.g. "." or ".."
#' * must not start with the reserved prefix "__".
#'
#' Only punctuation characters in the set `-, _, .` are allowed. As an extension
#' to the Zarr specification, characters and numbers can be any UTF-8 code
#' point. When portability is an issue, restrict characters and numbers to the
#' set `A-Za-z0-9`.
#' @param name Character string with a node name to check.
#' @return `TRUE` if the node name is valid, `FALSE` otherwise.
#' @docType methods
#' @export
#' @examples
#' is_valid_node_name("simple_name")
#' is_valid_node_name("no spaces allowed!")
is_valid_node_name <- function(name) {
  nzchar(name) > 0L &&
  !grepl('^\\.*$', name) &&
  !grepl('^__', name) &&
  grepl("^[\\p{L}\\p{M}\\p{N}\\._-]+$", name, perl = TRUE)
}

# This function takes a path and turns it into a key by stripping the leading /
.path2key <- function(path) {
  substr(path, 2L, 10000L)
}

# This function takes a path and turns it into a prefix that points to the same
# object as the path.
.path2prefix <- function(path) {
  paste0(substr(path, 2L, 10000L), '/')
}

# This function takes a prefix and turns it into a key that points to the same
# object as the prefix.
.prefix2key <- function(prefix) {
  sub('/$', '', prefix)
}

# This function takes a prefix and turns it into a path that points to the same
# object as the prefix.
.prefix2path <- function(prefix) {
  paste0('/', sub('/$', '', prefix))
}

# Parse the metadata to a list. Argument txt is a JSON object.
# This function has some error correction code to correct for known problems but
# most malformed JSON objects will fail hard.
.parse_metadata <- function(txt) {
  result <- tryCatch(
    jsonlite::fromJSON(txt, simplifyDataFrame = FALSE),
    error = function(e) {
      if (grepl("lexical error", conditionMessage(e))) {
        txt |>
          gsub(pattern = ":\\s*-Inf", replacement = ': "-Infinity"', x = _) |>
          gsub(pattern = ":\\s*Inf",  replacement = ': "Infinity"',  x = _) |>
          gsub(pattern = ":\\s*NaN",  replacement = ': "NaN"',       x = _) |>
          jsonlite::fromJSON(simplifyDataFrame = FALSE)
      } else {
        stop(e) # nocov
      }
    }
  )
  result
}

.size_string <- function(size_in_bytes) {
  if (size_in_bytes < 1024) {
    return(paste(size_in_bytes, "Bytes"))
  } else if (size_in_bytes < 1048576) {
    return(paste(round(size_in_bytes / 1024, 2), "KB"))
  } else if (size_in_bytes < 1073741824) {
    return(paste(round(size_in_bytes / 1048576, 2), "MB"))
  } else {
    return(paste(round(size_in_bytes / 1073741824, 2), "GB"))
  }
}

#' Convert a list into a data.frame while shortening long strings. List elements
#' are pasted together.
#' @param list A `list` with data to print, usually metadata.
#' @param width Maximum width of character entries. If entries are longer than
#'   width - 3, they are truncated and then '...' added.
#' @return data.frame with slim columns
#' @noRd
.slim.data.frame <- function(list, width = 50L) {
  maxw <- width - 3L
  len <- length(list)
  if (len) {
    out <- vector('character', len)
    for (i in seq(len)) {
      c <- list[[i]]
      c <- paste(c, collapse = ", ")
      if (nchar(c) > width)
        c <- paste0(substring(c, 1, maxw), '...')
      out[i] <- c
    }
    out <- data.frame(name = names(list), value = out)
    out
  } else data.frame()
}

#' Test if vectors `x` and `y` have near-identical values.
#' @noRd
.near <- function(x, y) {
  abs(x - y) <= pmax(Zarr.options$eps * pmax(abs(x), abs(y)), 1e-12)
}

#' Determines the protocol to be used with a specified store location.
#' @noRd
# Extend the existing .protocol() to recognize S3 locations, both the
# s3:// URI scheme and virtual-hosted/path-style https:// URLs.
.protocol <- function(loc) {
  if (grepl('^s3://', loc, ignore.case = TRUE) ||
      grepl('^https?://[^/]*s3[.-]?[a-z0-9-]*\\.amazonaws\\.com', loc, ignore.case = TRUE, perl = TRUE))
    's3'
  else if (grepl('^http(s)?://', loc, ignore.case = TRUE))
    'http'
  else
    'local'
}

# Parse an S3 location string into bucket, prefix and region. Accepts
# s3://bucket/prefix, virtual-hosted-style https URLs (bucket in the
# hostname), and path-style https URLs (bucket as the first path segment).
# Region is NULL when it can't be determined from the URL (s3:// scheme,
# or a *.s3.amazonaws.com host, which is the us-east-1 legacy global
# endpoint) - paws.storage's default provider chain then resolves it from
# AWS_REGION / the shared config file.
# NOTE: virtual-hosted-style parsing assumes the bucket name contains no
# dots - a known AWS ambiguity, not specific to this function.
.parse_s3_location <- function(loc) {
  if (grepl('^s3://', loc, ignore.case = TRUE)) {
    rest <- sub('^s3://', '', loc, ignore.case = TRUE)
    parts <- strsplit(rest, '/', fixed = TRUE)[[1L]]
    return(list(bucket = parts[1L],
                prefix = if (length(parts) > 1L) paste(parts[-1L], collapse = '/') else '',
                region = NULL, endpoint = NULL))
  }

  m <- regmatches(loc, regexec('^(https?)://([^/]+)/?(.*)$', loc, perl = TRUE))[[1L]]
  if (length(m) != 4L)
    stop('Cannot parse S3 location: ', loc, call. = FALSE) # nocov
  scheme <- m[2L]; host <- m[3L]; path <- m[4L]

  if (grepl('^s3[.-]?[a-z0-9-]*\\.amazonaws\\.com$', host, ignore.case = TRUE, perl = TRUE)) {
    # AWS path-style: https://s3[.region].amazonaws.com/bucket/prefix
    parts <- strsplit(path, '/', fixed = TRUE)[[1L]]
    region <- sub('^s3[.-]?', '', sub('\\.amazonaws\\.com$', '', host, ignore.case = TRUE), ignore.case = TRUE)
    return(list(bucket = parts[1L],
                prefix = if (length(parts) > 1L) paste(parts[-1L], collapse = '/') else '',
                region = if (nzchar(region)) region else NULL, endpoint = NULL))
  }

  m2 <- regmatches(host, regexec('^(.+)\\.s3[.-]?([a-z0-9-]*)\\.amazonaws\\.com$', host, perl = TRUE))[[1L]]
  if (length(m2) == 3L)
    # AWS virtual-hosted: https://bucket.s3[.-region].amazonaws.com/prefix
    return(list(bucket = m2[2L], prefix = path,
                region = if (nzchar(m2[3L])) m2[3L] else NULL, endpoint = NULL))

  # Generic S3-compatible endpoint (MinIO, EMBASSY Cloud, Ceph RGW, ...):
  # path-style is the only convention that works reliably without knowing
  # the provider's virtual-hosted addressing rules, so assume it - bucket
  # is the first path segment, the endpoint is the scheme+host itself.
  parts <- strsplit(path, '/', fixed = TRUE)[[1L]]
  if (!length(parts) || !nzchar(parts[1L]))
    stop('Cannot determine bucket from S3 location: ', loc, call. = FALSE) # nocov
  list(bucket = parts[1L],
       prefix = if (length(parts) > 1L) paste(parts[-1L], collapse = '/') else '',
       region = NULL, endpoint = paste0(scheme, '://', host))
}

#' Optimal chunking for an array
#'
#' This function computes the optimal dimension lengths of a single chunk from
#' the array dimensions as given in argument `dims`. "Optimal" means that the
#' provided solution is as close as possible to the `max_chunk` size.
#'
#' @param dims Integer array with the lengths along every dimension of the
#'   array.
#' @param max_chunk Optional. Integer giving the maximum number of elements per
#'   chunk. Defaults to `Zarr.options$chunk_length`.
#' @return An integer array with the same length as argument `dims` giving the
#'   length of a chunk along each dimension of the array.
#' @export
#' @examples
#' shape <- c(5000L, 43L, 12800L, 4L)
#' auto_chunk(shape)
#' auto_chunk(shape, 10000L)
auto_chunk <- function(dims, max_chunk = Zarr.options$chunk_length) {
  nchunks <- ceiling(dims / max_chunk)
  as.integer(ceiling(dims / nchunks))
}

#' Register a Zarr domain for this session
#' @param domain An instance of a class descending from `zarr_domain`.
#' @return Nothing.
#' @export
zarr_register_domain <- function(domain) {
  if (inherits(domain, "zarr_domain"))
    Zarr.domains[[domain$name]] <- domain
}

#' Unregister a Zarr domain from this session
#' @param domain The name of the `zarr_domain` to unregister.
#' @return Nothing.
#' @export
zarr_unregister_domain <- function(domain) {
  if (is.character(domain))
    rm(list = domain, envir = Zarr.domains, inherits = FALSE)
}

#' List the Zarr domains registered in this session
#' @return A list with instances of `zarr_domain` descendant classes.
#' @export
zarr_domains <- function() {
  as.list(Zarr.domains)
}

#' List the Zarr conventions supported by this release
#' @return A `data.frame` with descriptions of supported conventions.
#' @export
zarr_conventions <- function() {
  Zarr.options$conventions
}

#' Build a Zarr node
#'
#' This function polls the registered domains to see if they want to claim and
#' build the indicated node in the Zarr hierarchy. If no domain claims the node
#' a generic Zarr group or array is created.
#' @param name Character, the name of the node to be created.
#' @param metadata List, the metadata of the node to be created.
#' @param parent A `zarr_node`, the parent of the node to be created. `NULL` for
#'   the root node.
#' @return The newly created node, either from a domain or a generic
#'   `zarr_group` or `zarr_array`.
#' @noRd
.buildNode <- function(name, metadata, parent) {
  for (d in zarr_domains()) {
    node <- d$build(name, metadata, parent)
    if (inherits(node, 'zarr_node')) return(node)
  }

  # Fallback: return generic node
  if (metadata$node_type == 'group')
    zarr_group$new(name, metadata, parent, no_create_check = TRUE)
  else
    zarr_array$new(name, metadata, parent, no_create_check = TRUE)
}

# This internal function supports codec management for sharding
.build_codec_pipeline <- function(codec_configs, data_type, chunk_shape) {
  codecs <- list()
  for (cfg in codec_configs) {
    cdc <- switch(cfg$name,
      'transpose' = zarr_codec_transpose$new(length(chunk_shape), cfg$configuration),
      'bytes'     = zarr_codec_bytes$new(data_type, chunk_shape, cfg$configuration),
      'crc32c'    = zarr_codec_crc32c$new(),
      'blosc'     = zarr_codec_blosc$new(data_type = data_type, cfg$configuration),
      'zstd'      = zarr_codec_zstd$new(cfg$configuration),
      'gzip'      = zarr_codec_gzip$new(cfg$configuration),
      stop(paste('Unknown codec:', cfg$name), call. = FALSE)
    )
    codecs <- c(codecs, stats::setNames(list(cdc), cfg$name))
  }
  codecs
}

# Chunk element order. A Zarr chunk is serialised by its array->bytes codec in
# C order, after any array->array (transpose) codec has been applied. In R, the
# C-order serialisation of an array `y` is `as.vector(aperm(y, n:1))`, so the
# transpose codec and the serialisation together amount to a single
# permutation of an R-order chunk: `rev(order) + 1` with a transpose codec,
# `n:1` without one. These helpers apply that permutation once, instead of
# running the transpose codec and then permuting again for C order.

# The permutation from an R-order chunk of rank `n` to its serialised order,
# or `NULL` when the chunk is serialised in R order (the default transpose
# order `n-1, ..., 0` that this package writes).
.chunk_permutation <- function(codecs, n) {
  transp <- Filter(function(cdc) cdc$name == 'transpose', codecs)
  perm <- if (length(transp)) rev(transp[[1L]]$configuration$order) + 1L
          else rev(seq_len(n))
  if (identical(perm, seq_len(n))) NULL else perm
}

# aperm() keeps the bits but drops the class of integer64 data
.aperm <- function(x, perm) {
  out <- aperm(x, perm)
  if (inherits(x, 'integer64')) class(out) <- 'integer64'
  out
}

# Encode an R-order chunk `x` to raw bytes.
.encode_chunk <- function(x, codecs, perm) {
  if (!is.null(perm)) x <- .aperm(x, perm)
  for (cdc in codecs)
    if (cdc$name != 'transpose') x <- cdc$encode(x)
  x
}

# Decode raw chunk bytes to an R-order array of `shape`.
.decode_chunk <- function(raw, codecs, perm, shape) {
  for (cdc in rev(codecs))
    if (cdc$name != 'transpose') raw <- cdc$decode(raw)
  if (is.null(perm)) {
    dim(raw) <- shape
    raw
  } else {
    dim(raw) <- shape[perm]
    .aperm(raw, order(perm))
  }
}
