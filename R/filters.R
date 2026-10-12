# Zarr v.2 filters
#
# Zarr v.2 does not specify filters, but stores written by zarr-python use the
# filters of the Numcodecs package. Upon opening a v.2 store, the array metadata
# is converted to the v.3 format and the filters become codecs in the v.3
# pipeline, named "numcodecs.<id>" like zarr-python v.3 does: array -> array
# filters precede the array -> bytes codec, bytes -> bytes filters follow it. v.2
# stores are read-only so the filters only decode.

# Classification of the supported filters by their v.3 codec mode. The object
# codec "vlen-utf8" of "|O" arrays is not listed: it is the array -> bytes
# codec of the v.3 pipeline.
.v2_filter_modes <- c(delta = 'array', fixedscaleoffset = 'array', quantize = 'array',
                      bitround = 'array', astype = 'array', categorize = 'array',
                      packbits = 'array', shuffle = 'bytes', crc32 = 'bytes',
                      adler32 = 'bytes', fletcher32 = 'bytes')

# Parse a Numpy dtype string, such as "<i4" or "|b1", into a Zarr v.3 data type
# name, the endianness and the size in bytes. Character string types all map to
# "string".
.numpy_dtype <- function(x) {
  m <- regmatches(x, regexec('^([<>|=]?)([bfiuOSU])([0-9]*)$', x))[[1L]]
  if (!length(m))
    stop('Unsupported Numpy data type: ', x, call. = FALSE)
  size <- as.integer(m[4L])
  list(data_type = switch(m[3L],
                          b = 'bool',
                          f = paste0('float', 8L * size),
                          i = paste0('int', 8L * size),
                          u = paste0('uint', 8L * size),
                          'string'),
       endian = if (m[2L] == '>') 'big' else 'little',
       size = size)
}

# The Numpy dtype string of the data encoded by filter `id` with configuration
# `conf`, or NULL if the filter does not change the data type.
.v2_encoded_dtype <- function(id, conf) {
  switch(id,
         delta            = ,
         fixedscaleoffset = conf$astype,
         astype           = conf$encode_dtype,
         categorize       = conf$astype %||% '|u1',
         packbits         = '|u1',
         NULL)
}

# Convert x to the R type that represents Zarr data type dt.
.as_rtype <- function(x, dt) {
  switch(dt$Rtype,
         integer   = as.integer(x),
         integer64 = bit64::as.integer64(x),
         double    = as.double(x),
         logical   = as.logical(x),
         character = as.character(x))
}

# Insert the v.2 filters into the list of v.3 codec metadata fragments built
# from the v.2 metadata, `codecs`, returning the updated list. If an array ->
# array filter changes the data type, the array -> bytes codec is replaced by a
# "bytes" codec for the encoded data type.
.v2_filters_to_v3 <- function(filters, codecs) {
  filters <- Filter(function(f) f$id != 'vlen-utf8', filters)
  if (!length(filters)) return(codecs)

  ids <- vapply(filters, function(f) f$id, '')
  modes <- .v2_filter_modes[ids]
  if (anyNA(modes))
    stop('Unsupported Zarr v.2 filter: ', ids[is.na(modes)][1L], call. = FALSE)
  if (is.unsorted(match(modes, c('array', 'bytes'))))
    stop('Zarr v.2 filter order cannot be expressed in Zarr v.3: ', paste(ids, collapse = ', '), call. = FALSE)

  frags <- lapply(filters, function(f)
    list(name = paste0('numcodecs.', f$id), configuration = f[names(f) != 'id']))

  # The last array -> array filter that changes the data type sets the type to
  # serialize. Filters are given in encoding order.
  enc <- NULL
  for (f in filters[modes == 'array'])
    enc <- .v2_encoded_dtype(f$id, f) %||% enc

  ab <- which(vapply(codecs, function(c) c$name %in% c('bytes', 'vlen-utf8', 'ucs-4'), TRUE))
  if (!is.null(enc)) {
    enc <- .numpy_dtype(enc)
    codecs[[ab]] <- if (enc$size > 1L) list(name = 'bytes', configuration = list(endian = enc$endian))
                    else list(name = 'bytes')
  }

  codecs <- append(codecs, frags[modes == 'bytes'], after = ab)
  append(codecs, frags[modes == 'array'], after = ab - 1L)
}

# The data type that the array -> bytes codec serializes, following the array
# -> array codecs in `codecs` from the array data type `data_type`.
.encoded_data_type <- function(codecs, data_type) {
  for (cdc in codecs)
    if (inherits(cdc, 'zarr_filter'))
      data_type <- cdc$encoded_type %||% data_type
  data_type
}

# Create a filter codec from its v.3 name "numcodecs.<id>" and configuration.
.zarr_filter <- function(name, configuration) {
  id <- sub('^numcodecs\\.', '', name)
  switch(id,
    delta            = zarr_filter_delta$new(configuration),
    fixedscaleoffset = zarr_filter_fixedscaleoffset$new(configuration),
    quantize         = ,
    bitround         = zarr_filter$new(id, configuration),
    astype           = zarr_filter_astype$new(configuration),
    categorize       = zarr_filter_categorize$new(configuration),
    packbits         = zarr_filter_packbits$new(configuration),
    shuffle          = zarr_filter_shuffle$new(configuration),
    crc32            = ,
    adler32          = ,
    fletcher32       = zarr_filter_checksum$new(id, configuration),
    stop('Unknown codec: ', name, call. = FALSE)
  )
}

# ======= zarr_filter ==========================================================

#' Zarr v.2 filters
#'
#' @description Zarr v.2 filters are transformations of chunk data that were
#'   not specified by Zarr v.2 itself but by the Numcodecs package that
#'   zarr-python uses. When a Zarr v.2 store is opened, the filters become
#'   codecs in the Zarr v.3 codec pipeline of an array, with a name of
#'   "numcodecs.<id>". Because Zarr v.2 stores are read-only in this package,
#'   filters only decode data.
#'
#'   This class is the ancestor of all filters. It also implements the lossy
#'   "quantize" and "bitround" filters: these reduce the precision of floating
#'   point data upon encoding but they leave the data type unchanged, so
#'   decoding is the identity.
#'
#'   The following filters are supported: "delta", "fixedscaleoffset",
#'   "quantize", "bitround", "astype", "categorize", "packbits", "shuffle",
#'   "crc32", "adler32" and "fletcher32". The "vlen-utf8" filter is supported
#'   through [zarr_codec_vlenutf8].
#' @docType class
zarr_filter <- R6::R6Class('zarr_filter',
  inherit = zarr_codec,
  cloneable = FALSE,
  private = list(
    # The data type of the decoded data, a zarr_data_type instance, if set by
    # the filter configuration.
    .dtype = NULL,

    # The data type of the encoded data, a zarr_data_type instance, or NULL
    # when the filter does not change the data type.
    .encoded_type = NULL,

    print_configuration = function() {
      conf <- private$.configuration
      if (length(conf)) {
        cat('Configuration:\n')
        for (nm in names(conf))
          cat(' ', nm, ':', paste(conf[[nm]], collapse = ', '), '\n')
      }
    }
  ),
  public = list(
    #' @description Create a new filter object.
    #' @param id The Numcodecs identifier of the filter, such as "delta".
    #' @param configuration A list with the configuration parameters of the
    #'   filter, as found in the Zarr v.2 metadata but without the "id"
    #'   element.
    #' @param from,to The input and output data object for the encoding
    #'   operation, either "array" or "bytes".
    #' @return An instance of this class.
    initialize = function(id, configuration, from = 'array', to = 'array') {
      super$initialize(paste0('numcodecs.', id), configuration)
      private$.from <- from
      private$.to <- to

      dec <- configuration$dtype %||% configuration$decode_dtype
      if (!is.null(dec))
        private$.dtype <- zarr_data_type$new(.numpy_dtype(dec)$data_type)
      enc <- .v2_encoded_dtype(id, configuration)
      if (!is.null(enc))
        private$.encoded_type <- zarr_data_type$new(.numpy_dtype(enc)$data_type)
    },

    #' @description Create a new, independent copy of this filter.
    #' @return An instance of the same class as this filter.
    copy = function() {
      .zarr_filter(private$.name, private$.configuration)
    },

    #' @description Filters can only decode data: Zarr v.2 stores are
    #'   read-only.
    #' @param data Ignored.
    #' @return This method always throws an error.
    encode = function(data) {
      stop('Zarr v.2 filter "', private$.name, '" can only decode data', call. = FALSE)
    }
  ),
  active = list(
    #' @field encoded_type (read-only) The [zarr_data_type] of the encoded
    #'   data, or `NULL` if the filter does not change the data type. This is
    #'   the data type that the "bytes" codec must deserialize.
    encoded_type = function(value) {
      if (missing(value))
        private$.encoded_type
    }
  )
)

# ======= zarr_filter_delta ====================================================

#' Zarr v.2 "delta" filter
#'
#' @description The "delta" filter encodes data as the difference between
#'   adjacent elements, with the first element stored as is. Decoding is a
#'   cumulative sum in the decoded data type, wrapping around on overflow for
#'   integer data types up to 32 bits, like Numpy does. 64-bit integers do not
#'   wrap around: an overflow yields `NA`.
#' @docType class
zarr_filter_delta <- R6::R6Class('zarr_filter_delta',
  inherit = zarr_filter,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "delta" filter.
    #' @param configuration A list with elements `dtype` and, optionally,
    #'   `astype`.
    #' @return An instance of this class.
    initialize = function(configuration) {
      super$initialize('delta', configuration)
    },

    #' @description Decode the data.
    #' @param data The encoded data.
    #' @return The decoded data.
    decode = function(data) {
      dt <- private$.dtype
      out <- if (dt$Rtype == 'integer64') {
        x <- cumsum(bit64::as.integer64(data))
        if (dt$data_type == 'uint32') x %% bit64::as.integer64(4294967296) else x
      } else {
        x <- cumsum(as.double(data))
        if (dt$Rtype == 'integer') {
          lo <- if (dt$signed) -2^(8L * dt$size - 1L) else 0
          (x - lo) %% 2^(8L * dt$size) + lo
        } else x
      }
      .as_rtype(out, dt)
    }
  )
)

# ======= zarr_filter_fixedscaleoffset =========================================

#' Zarr v.2 "fixedscaleoffset" filter
#'
#' @description The "fixedscaleoffset" filter encodes data as `round((x -
#'   offset) * scale)`, typically in a smaller integer data type. Decoding
#'   computes `x / scale + offset`, truncated towards zero when the decoded data
#'   type is an integer type, like Numpy does.
#' @docType class
zarr_filter_fixedscaleoffset <- R6::R6Class('zarr_filter_fixedscaleoffset',
  inherit = zarr_filter,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "fixedscaleoffset" filter.
    #' @param configuration A list with elements `scale`, `offset`, `dtype`
    #'   and, optionally, `astype`.
    #' @return An instance of this class.
    initialize = function(configuration) {
      super$initialize('fixedscaleoffset', configuration)
    },

    #' @description Decode the data.
    #' @param data The encoded data.
    #' @return The decoded data.
    decode = function(data) {
      conf <- private$.configuration
      .as_rtype(as.double(data) / conf$scale + conf$offset, private$.dtype)
    }
  )
)

# ======= zarr_filter_astype ===================================================

#' Zarr v.2 "astype" filter
#'
#' @description The "astype" filter converts data to another data type.
#'   Decoding converts the data back to the decoded data type, truncating
#'   towards zero when converting floating point values to an integer type.
#' @docType class
zarr_filter_astype <- R6::R6Class('zarr_filter_astype',
  inherit = zarr_filter,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "astype" filter.
    #' @param configuration A list with elements `encode_dtype` and
    #'   `decode_dtype`.
    #' @return An instance of this class.
    initialize = function(configuration) {
      super$initialize('astype', configuration)
    },

    #' @description Decode the data.
    #' @param data The encoded data.
    #' @return The decoded data.
    decode = function(data) {
      .as_rtype(data, private$.dtype)
    }
  )
)

# ======= zarr_filter_categorize ===============================================

#' Zarr v.2 "categorize" filter
#'
#' @description The "categorize" filter encodes character strings as the
#'   1-based index into a vector of labels. Strings that are not a label are
#'   encoded as 0, which decodes to an empty string, like with Numcodecs.
#' @docType class
zarr_filter_categorize <- R6::R6Class('zarr_filter_categorize',
  inherit = zarr_filter,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "categorize" filter.
    #' @param configuration A list with elements `labels`, `dtype` and,
    #'   optionally, `astype`.
    #' @return An instance of this class.
    initialize = function(configuration) {
      super$initialize('categorize', configuration)
    },

    #' @description Decode the data.
    #' @param data The encoded data.
    #' @return A character vector with the decoded data.
    decode = function(data) {
      c('', unlist(private$.configuration$labels))[as.integer(data) + 1L]
    }
  )
)

# ======= zarr_filter_packbits =================================================

#' Zarr v.2 "packbits" filter
#'
#' @description The "packbits" filter packs logical values into bits, most
#'   significant bit first. The first byte of the encoded data gives the number
#'   of bits that pad the final byte.
#' @docType class
zarr_filter_packbits <- R6::R6Class('zarr_filter_packbits',
  inherit = zarr_filter,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "packbits" filter.
    #' @param configuration Ignored, the filter has no configuration
    #'   parameters.
    #' @return An instance of this class.
    initialize = function(configuration = list()) {
      super$initialize('packbits', list())
      private$.dtype <- zarr_data_type$new('bool')
    },

    #' @description Decode the data.
    #' @param data The encoded data, an integer vector of byte values.
    #' @return A logical vector with the decoded data.
    decode = function(data) {
      bits <- matrix(rawToBits(as.raw(data[-1L])), nrow = 8L)[8L:1L, ]
      out <- as.logical(bits)
      out[seq_len(length(out) - data[1L])]
    }
  )
)

# ======= zarr_filter_shuffle ==================================================

#' Zarr v.2 "shuffle" filter
#'
#' @description The "shuffle" filter rearranges the bytes of the data such
#'   that the first bytes of all elements come first, then all second bytes,
#'   and so on. This improves compression of the data.
#' @docType class
zarr_filter_shuffle <- R6::R6Class('zarr_filter_shuffle',
  inherit = zarr_filter,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "shuffle" filter.
    #' @param configuration A list with element `elementsize`, the size of the
    #'   data elements in bytes, by default 4.
    #' @return An instance of this class.
    initialize = function(configuration) {
      super$initialize('shuffle', configuration, from = 'bytes', to = 'bytes')
    },

    #' @description Decode the data.
    #' @param data The encoded data, a raw vector.
    #' @return A raw vector with the decoded data.
    decode = function(data) {
      size <- as.integer(private$.configuration$elementsize %||% 4L)
      if (size <= 1L) return(data)
      if (length(data) %% size)
        stop('Shuffled data is not an integer multiple of the element size', call. = FALSE)
      as.vector(t(matrix(data, ncol = size)))
    }
  )
)

# ======= zarr_filter_checksum =================================================

#' Zarr v.2 checksum filters
#'
#' @description The "crc32", "adler32" and "fletcher32" filters add a 32-bit
#'   checksum to the data, in little-endian byte order. The "crc32" and
#'   "adler32" checksums are placed at the start of the data unless the
#'   configuration has a `location` of "end"; the "fletcher32" checksum is
#'   always placed at the end. Decoding strips the checksum and verifies it
#'   against the data: if the two don't match a warning is generated.
#'
#'   The "fletcher32" checksum is the HDF5 variant. The two 16-bit sums are
#'   verified modulo 65535 because the HDF5 algorithm does not reduce a sum of
#'   65535 to 0.
#' @docType class
zarr_filter_checksum <- R6::R6Class('zarr_filter_checksum',
  inherit = zarr_filter,
  cloneable = FALSE,
  private = list(
    # Compute the checksum of raw vector x, returning the two 16-bit sums as a
    # numeric vector with the low sum first. Not used for crc32.
    sums = function(x, modulus) {
      if (private$.name == 'numcodecs.fletcher32') {
        if (length(x) %% 2L) x <- c(x, as.raw(0L))
        b <- matrix(as.numeric(x), nrow = 2L)
        x <- 256 * b[1L, ] + b[2L, ]
        lo <- 0
      } else {
        x <- as.numeric(x)
        lo <- 1
      }
      n <- length(x)
      c((lo + sum(x)) %% modulus,
        (lo * n + sum((x * ((n - seq_len(n) + 1) %% modulus)) %% modulus)) %% modulus)
    }
  ),
  public = list(
    #' @description Create a new checksum filter.
    #' @param id The Numcodecs identifier of the filter, one of "crc32",
    #'   "adler32" or "fletcher32".
    #' @param configuration A list with the configuration parameters of the
    #'   filter, optionally with element `location` for "crc32" and "adler32".
    #' @return An instance of this class.
    initialize = function(id, configuration = list()) {
      if (id == 'crc32' && !requireNamespace('digest'))
        stop('Must install package "digest" for this functionality', call. = FALSE) # nocov

      super$initialize(id, configuration, from = 'bytes', to = 'bytes')
    },

    #' @description Strip the checksum from the data and verify it.
    #' @param data The encoded data, a raw vector.
    #' @return A raw vector with the decoded data.
    decode = function(data) {
      len <- length(data)
      at_end <- private$.name == 'numcodecs.fletcher32' ||
                identical(private$.configuration$location, 'end')
      ndx <- if (at_end) (len - 3L):len else 1L:4L
      out <- data[-ndx]
      stored <- as.numeric(data[ndx])

      ok <- switch(private$.name,
        numcodecs.crc32 = {
          calc <- as.numeric(paste0('0x', digest::digest(out, algo = 'crc32', serialize = FALSE)))
          sum(stored * 256^(0:3)) == calc
        },
        numcodecs.adler32 = {
          s <- private$sums(out, 65521)
          sum(stored * 256^(0:3)) == s[1L] + 65536 * s[2L]
        },
        numcodecs.fletcher32 = {
          s <- private$sums(out, 65535)
          all(c(stored[1L] + 256 * stored[2L], stored[3L] + 256 * stored[4L]) %% 65535 == s)
        })
      if (!ok)
        warning('Checksum failed on raw data object!', call. = FALSE)
      out
    }
  )
)
