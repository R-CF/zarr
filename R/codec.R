#' Zarr codecs
#'
#' @description Zarr codecs encode data from the user data to stored data, using
#' one or more transformations, such as compression. Decoding of stored data is
#' the inverse process, whereby the codecs are applied in reverse order.
#' @docType class
zarr_codec <- R6::R6Class('zarr_codec',
  inherit = zarr_extension,
  cloneable = FALSE,
  private = list(
    # The configuration parameters of the codec
    .configuration = list(),

    # The input and output data object for the encoding operation
    .from = 'array',
    .to   = 'bytes'
  ),
  public = list(
    #' @description Create a new codec object.
    #' @param name The name of the codec, a single character string.
    #' @param configuration A list with the configuration parameters for this
    #'   codec.
    #' @return An instance of this class.
    initialize = function(name, configuration) {
      super$initialize(name)
      private$.configuration <- configuration
    },

    #' @description This method gives the operating mode of the encoding
    #'   operation of the codec in form of a string "array -> array", "array ->
    #'   bytes" or "bytes -> bytes".
    mode = function() {
      paste(private$.from, private$.to, sep = ' -> ')
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      if (length(private$.configuration))
        list(name = private$.name, configuration = private$.configuration)
      else
        list(name = private$.name)
    },

    #' @description This method encodes a data object but since this is the base
    #' codec class the "encoding" is a no-op.
    #' @param data The data to be encoded.
    #' @return The encoded data object, unaltered.
    encode = function(data) {
      data
    },

    #' @description This method decodes a data object but since this is the base
    #' codec class the "decoding" is a no-op.
    #' @param data The data to be decoded.
    #' @return The decoded data object, unaltered.
    decode = function(data) {
      data
    }
  ),
  active = list(
    #' @field from (read-only) Character string that indicates the source data
    #' type of this codec, either "array" or "bytes".
    from = function(value) {
      if (missing(value))
        private$.from
    },

    #' @field to (read-only) Character string that indicates the output data
    #' type of this codec, either "array" or "bytes".
    to = function(value) {
      if (missing(value))
        private$.to
    },

    #' @field configuration (read-only) A list with the configuration parameters
    #'   of the codec, exactly like they are defined in Zarr. This field is
    #'   read-only but each codec class has fields to set individual parameters.
    configuration = function(value) {
      if (missing(value))
        private$.configuration
    }
  )
)

#' Zarr transpose codec
#'
#' @description The Zarr "transpose" codec registers the storage order of a data
#'   object relative to the canonical row-major ordering of Zarr. If the
#'   registered ordering is different from the native ordering on the platform
#'   where the array is being read, the data object will be permuted upon
#'   reading.
#'
#'   R data is arranged in column-major order. The most efficient storage
#'   arrangement between Zarr and R is thus column-major ordering, avoiding
#'   encoding to the canonical row-major ordering during storage and decoding to
#'   column-major ordering during a read. If the storage arrangement is not
#'   row-major ordering, a transpose codec must be added to the array
#'   definition. Note that within R, both writing and reading are no-ops when
#'   data is stored in column-major ordering. On the other hand, when no
#'   transpose codec is defined for the array, there will be an automatic
#'   transpose of the data on writing and reading to maintain compatibility with
#'   the Zarr specification. Using the [array_builder] will automatically add
#'   the transpose codec to the array definition.
#'
#'   For maximum portability (e.g. with Zarr implementations outside of R that
#'   do not implement the transpose codec), data should be stored in row-major
#'   order, which can be achieved by not including this codec in the array
#'   definition.
#' @docType class
zarr_codec_transpose <- R6::R6Class('zarr_codec_transpose',
  inherit = zarr_codec,
  cloneable = FALSE,
  private = list (
    # Check if the "order" argument is valid. Returns TRUE or FALSE. "order"
    # must have been cast to integer.
    check_order = function(order, len) {
      !is.null(order) && is.integer(order) && length(order) == len &&
      all(order >= 0L & order < len) && anyDuplicated(order) == 0L
    }
  ),
  public = list(
    #' @description Create a new "transpose" codec object.
    #' @param shape The shape of the array that this codec operates on.
    #' @param configuration Optional. A list with the configuration parameters
    #'   for this codec. The element `order` specifies the ordering of the
    #'   dimensions of the shape relative to the Zarr canonical arrangement. An
    #'   integer vector with a length equal to the dimensions of argument
    #'   `shape`. The ordering must be 0-based. If not given, the default R
    #'   ordering is used.
    #' @return An instance of this class.
    initialize = function(shape, configuration = list()) {
      if ((shape_len <- length(shape)) < 2L)
        stop('Can only set a transpose codec on a matrix or array.', call. = FALSE) # nocov

      if (!length(configuration))
        configuration <- list(order = seq(shape_len - 1L, 0L, -1L))
      else if (!private$check_order(configuration$order, shape_len))
        stop('Dimension ordering does not match the shape.', call. = FALSE) # nocov

      super$initialize('transpose', configuration)
      private$.from <- 'array'
      private$.to <- 'array'
    },

    #' @description This method permutes a data object to match the desired
    #' dimension ordering.
    #' @param data The data to be permuted, an R matrix or array.
    #' @return The permuted data object, a matrix or array in Zarr store
    #' dimension order.
    encode = function(data) {
      if (all(diff(private$.configuration$order) == -1L))
        # Store in native R order - no-op
        data
      else
        aperm(data, perm = rev(private$.configuration$order) + 1L)
    },

    #' @description This method permutes a data object from a Zarr store to an
    #' R matrix or array.
    #' @param data The data to be permuted, from a Zarr store.
    #' @return The permuted data object, an R matrix or array.
    decode = function(data) {
      if (all(diff(private$.order) == -1L))
        # Stored in native R order - no-op
        data
      else
        aperm(data, perm = rev(private$.configuration$order) + 1L)
    }
  ),
  active = list(
    #' @field order Set or retrieve the 0-based ordering of the dimensions of
    #' the array when storing
    order = function(value) {
      if (missing(value))
        private$.configuration$order
      else if (private$check_order(value, length(private$.configuration$order)))
        private$.configuration$order <- value
      else
        stop('Dimension ordering does not match the shape.', call. = FALSE) # nocov
    }
  )
)

#' Zarr bytes codec
#'
#' @description The Zarr "bytes" codec encodes an R data object to a raw byte
#'   string, and decodes a raw byte string to a R object, possibly inverting the
#'   endianness of the data in the operation.
#' @docType class
zarr_codec_bytes <- R6::R6Class('zarr_codec_bytes',
  inherit = zarr_codec,
  cloneable = FALSE,
  private = list(
    # The data type of the object that this codec operates on, an instance of
    # the data_type extension object.
    .data_type = NULL
  ),
  public = list(
    #' @description Create a new "bytes" codec object.
    #' @param data_type The [zarr_data_type] instance of the Zarr array that
    #'   this codec is used for.
    #' @param configuration Optional. A list with the configuration parameters
    #'   for this codec. The element `endian` specifies the byte ordering of the
    #'   data type of the Zarr array. A string with value "big" or "little". If
    #'   not given, the default endianness of the platform is used.
    #' @return An instance of this class.
    initialize = function(data_type, configuration = NULL) {
      if (inherits(data_type, 'zarr_data_type'))
        private$.data_type <- data_type
      else
        stop('Codec must be initialized with a `zarr_data_type` instance.', call. = FALSE) # nocov

      if (is.null(configuration))
        configuration <- list(endian = .Platform$endian)
      else if (!is.list(configuration))
        stop('`configuration` parameter must be a list.', call. = FALSE) # nocov

      super$initialize('bytes', configuration)
      private$.from <- 'array'
      private$.to <- 'bytes'

      self$endian <- configuration$endian
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      if (private$.data_type$size > 1L)
        list(name = 'bytes',
             configuration = list(endian = private$.configuration$endian))
      else
        list(name = 'bytes')
    },

    #' @description This method writes an R object to a raw vector in the data
    #'   type of the Zarr array. Prior to writing, any `NA` values are assigned
    #'   the `fill_value` of the `data_type` of the Zarr array. Note that the
    #'   logical type cannot encode `NA` in Zarr and any `NA` values are set to
    #'   `FALSE`.
    #' @param data The data to be encoded.
    #' @return A raw vector with the encoded data object.
    encode = function(data) {
      dt <- private$.data_type
      data[is.na(data)] <- dt$fill_value

      if (dt$data_type == 'logical') {
        as.raw(as.integer(data))
      } else if (dt$data_type == 'integer64') {
        writeBin(unclass(data), raw(), endian = private$.configuration$endian)
      } else
        writeBin(data, raw(), size = dt$size, endian = private$.configuration$endian)
    },

    #' @description This method takes a raw vector and converts it to an R
    #'   object of an appropriate type. For all types other than logical, any
    #'   data elements with the `fill_value` of the Zarr data type are set to
    #'   `NA`.
    #' @param data The data to be decoded.
    #' @return An R object with the shape of a chunk from the array.
    decode = function(data) {
      dt <- private$.data_type
      n <- length(data) %/% dt$size
      if (n %% dt$size)
        stop('Data length not a multiple of data type size.', call. = FALSE) # nocov

      out <- if (dt$data_type == 'logical') {
        as.logical(as.integer(data))
      } else if (dt$data_type == 'integer64') {
        vals <- readBin(data, what = 'double', n = n, endian = private$.configuration$endian)
        class(vals) <- 'integer64'
        vals
      } else {
        readBin(data, what = dt$Rtype, size = dt$size, signed = dt$signed,
                n = n, endian = private$.configuration$endian)
      }

      if (dt$data_type != 'logical')
        out[out == dt$fill_value] <- NA

      out
    }
  ),
  active = list(
    #' @field endian Set or retrieve the endianness of the storage of the data
    #' with this codec. A string with value of "big" or "little".
    endian = function(value) {
      if (missing(value))
        private$.configuration$endian
      else if (is.character(value) && length(value) == 1L && value %in% c("big", "little"))
        private$.configuration$endian <- value
      else
        stop('Bad value for endianness of the data.', call. = FALSE) # nocov
    }
  )
)

#' Zarr blosc codec
#'
#' @description The Zarr "blosc" codec offers a number of compression options to
#'   reduce the size of a raw vector prior to storing, and uncompressing when
#'   reading.
#' @docType class
zarr_codec_blosc <- R6::R6Class('zarr_codec_blosc',
  inherit = zarr_codec,
  cloneable = FALSE,
  private = list(
    # The zarr_data_type of the array using this codec.
    .data_type = NULL,

    # Check the configuration parameters. Conf must be a list. If ok, the list
    # is returned. If not ok, an error is thrown.
    check_configuration = function(conf) {
      if (is.null(conf$cname))
        conf$cname <- 'zstd'
      else if (!is.character(conf$cname) || !(length(conf$cname) == 1L) ||
               !(conf$cname %in% c("blosclz", "lz4", "lz4hc", "zstd", "zlib")))
        stop('Blosc configuration has bad compression name.', call. = FALSE) # nocov

      if (is.null(conf$clevel))
        conf$clevel <- 1L
      else if (!is.numeric(conf$clevel) || !(length(conf$clevel) == 1L) ||
               !(conf$clevel >= 0 && conf$clevel <= 9))
        stop('Blosc parameter clevel must be a single integer value between 0 and 9.', call. = FALSE) # nocov

      if (is.null(conf$shuffle))
        conf$shuffle <-
          if (private$.data_type$data_type %in% c('bool', 'int8', 'uint8')) 'noshuffle'
          else if (private$.data_type$data_type %in% c('int16', 'uint16', 'int32', 'uint32', 'int64', 'float32')) 'shuffle'
          else 'bitshuffle'
      else if (!is.character(conf$shuffle) || !(length(conf$shuffle) == 1L) ||
               !(conf$shuffle %in% c('shuffle', 'noshuffle', 'bitshuffle')))
        stop('Bad blosc shuffle parameter.', call. = FALSE) # nocov

      if (is.null(conf$typesize))
        conf$typesize <- private$.data_type$size
      else if (!is.integer(conf$typesize) || !(length(conf$typesize) == 1L) ||
               !(conf$typesize %in% c(1L, 2L, 4L, 8L)))
        stop('Blosc typesize parameter must be 1, 2, 4 or 8.', call. = FALSE) # nocov

      if (is.null(conf$blocksize))
        conf$blocksize <- 0L
      else if (!is.integer(conf$blocksize) || !(length(conf$blocksize) == 1L))
        stop('Blosc blocksize parameter must be a single integer value.', call. = FALSE) # nocov

      conf
    }
  ),
  public = list(
    #' @description Create a new "blosc" codec object. The typesize argument is
    #'   taken from the data type of the array passed in through the `data_type`
    #'   argument and the shuffle argument is chosen based on the `data_type`.
    #' @param data_type The [zarr_data_type] instance of the Zarr array that
    #'   this codec is used for.
    #' @param configuration Optional. A list with the configuration parameters
    #'   for this codec. If not given, the default compression of "zstd" with
    #'   level 1 will be used.
    #' @return An instance of this class.
    initialize = function(data_type, configuration = NULL) {
      if (!requireNamespace('blosc'))
        stop('Must install package "blosc" for this functionality', call. = FALSE) # nocov

      if (!inherits(data_type, 'zarr_data_type'))
        stop('Codec must be initialized with a `zarr_data_type` instance.', call. = FALSE) # nocov
      else
        private$.data_type <- data_type

      if (is.null(configuration))
        configuration <- list()
      else if (!is.list(configuration))
        stop('`configuration` parameter must be a list.', call. = FALSE) # nocov
      configuration <- private$check_configuration(configuration)

      super$initialize('blosc', configuration)
      private$.from <- 'bytes'
      private$.to <- 'bytes'
    },

    #' @description This method compresses a data object using the "blosc"
    #' compression library.
    #' @param data The raw vector to be compressed.
    #' @return A raw vector with compressed data.
    encode = function(data) {
      if (is.raw(data))
        blosc::blosc_compress(data, compressor = private$.configuration$cname,
                              level = private$.configuration$clevel,
                              shuffle = private$.configuration$shuffle,
                              typesize = private$.configuration$typesize,
                              blocksize = private$.configuration$blocksize)
      else
        stop('Blosc codec should be passed a raw vector.', call. = FALSE)
    },

    #' @description This method decompresses a data object using the "blosc"
    #' compression library.
    #' @param data The raw vector to be decoded.
    #' @return A raw vector with the decoded data.
    decode = function(data) {
      if (is.raw(data))
        blosc::blosc_decompress(data)
      else
        stop('Blosc codec should be passed a raw vector.', call. = FALSE)
    }
  ),
  active = list(
    #' @field cname Set or retrieve the name of the compression algorithm. Must
    #'   be one of "blosclz", "lz4", "lz4hc", "zstd" or "zlib".
    cname = function(value) {
      if (missing(value))
        private$.configuration$cname
      else {
        conf <- private$.configuration
        conf$cname <- value
        private$.configuration <- private$check_configuration(conf)
      }
    },

    #' @field clevel Set or retrieve the compression level. Must
    #'   be an integer between 0 (no compression) and 9 (maximum compression).
    clevel = function(value) {
      if (missing(value))
        private$.configuration$clevel
      else {
        conf <- private$.configuration
        conf$clevel <- as.integer(value)
        private$.configuration <- private$check_configuration(conf)
      }
    },

    #' @field shuffle Set or retrieve the data shuffling of the compression
    #'   algorithm. Must be one of "shuffle", "noshuffle" or "bitshuffle".
    shuffle = function(value) {
      if (missing(value))
        private$.configuration$shuffle
      else {
        conf <- private$.configuration
        conf$shuffle <- value
        private$.configuration <- private$check_configuration(conf)
      }
    },

    #' @field typesize Set or retrieve the size in bytes of the data type being
    #'   compressed. It is highly recommended to leave this at the automatically
    #'   determined value.
    typesize = function(value) {
      if (missing(value))
        private$.configuration$typesize
      else {
        conf <- private$.configuration
        conf$typesize <- value
        private$.configuration <- private$check_configuration(conf)
      }
    },

    #' @field blocksize Set or retrieve the size in bytes of the blocks being
    #'   compressed. It is highly recommended to leave this at a value of 0 such
    #'   that the blosc library will automatically determine the optimal value.
    blocksize = function(value) {
      if (missing(value))
        private$.configuration$blocksize
      else {
        conf <- private$.configuration
        conf$blocksize <- value
        private$.configuration <- private$check_configuration(conf)
      }
    }
  )
)

#' Zarr gzip codec
#'
#' @description The Zarr "gzip" codec compresses a raw vector prior to storing,
#'   and uncompresses the raw vector when reading.
#' @docType class
zarr_codec_gzip <- R6::R6Class('zarr_codec_gzip',
  inherit = zarr_codec,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "gzip" codec object.
    #' @param configuration Optional. A list with the configuration parameters
    #'   for this codec. The element `level` specifies the compression level of
    #'   this codec, ranging from 0 (no compression) to 9 (maximum compression).
    #' @return An instance of this class.
    initialize = function(configuration = NULL) {
      if (!requireNamespace('zlib'))
        stop('Must install package "zlib" for this functionality', call. = FALSE) # nocov

      if (is.null(configuration))
        configuration <- list(level = 6)
      else if (!is.list(configuration) || is.null(configuration$level))
        stop('`configuration` argument must be a list with a field `level`.', call. = FALSE) # nocov
      else if (!is.integer(configuration$level) || length(configuration$level) != 1L ||
               !(configuration$level >= 0 && configuration$level <= 9))
        stop('Configuration parameter `level` must be a single integer value between 0 and 9.', call. = FALSE) # nocov

      super$initialize('gzip', configuration)

      private$.from <- 'bytes'
      private$.to <- 'bytes'
    },

    #' @description This method encodes a data object.
    #' @param data The data to be encoded.
    #' @return The encoded data object.
    encode = function(data) {
      zlib::compress(data, level = private$.configuration$level, wbits = 31)
    },

    #' @description This method decodes a data object.
    #' @param data The data to be decoded.
    #' @return The decoded data object.
    decode = function(data) {
      zlib::decompress(data, wbits = 31)
    }
  ),
  active = list(
    #' @field level The compression level of the gzip codec, an integer value
    #' between 0L (no compression) and 9 (maximum compression).
    level = function(value) {
      if (missing(value))
        private$.configuration$level
      else {
        value <- as.integer(value)
        if (length(value) == 1L && value >= 0 && value <= 9)
          private$.configuration$level <- as.integer(value)
        else
          stop('Compression level of gzip must be an integer value between 0 and 9.', call. = FALSE) # nocov
      }
    }
  )
)

#' Zarr CRC32C codec
#'
#' @description The Zarr "CRC32C" codec computes a 32-bit checksum of a raw
#'   vector. Upon encoding the codec appends the checksum to the end of the
#'   vector. When decoding, the final 4 bytes from the raw vector are extracted
#'   and compared to the checksum of the remainder of the raw vector - if the
#'   two don't match a warning is generated.
#' @docType class
zarr_codec_crc32c <- R6::R6Class('zarr_codec_crc32c',
  inherit = zarr_codec,
  cloneable = FALSE,
  public = list(
    #' @description Create a new "crc32c" codec object.
    #' @param configuration Optional. A list with the configuration parameters
    #'   for this codec but since this codec doesn't have any the argument is
    #'   always ignored.
    #' @return An instance of this class.
    initialize = function() {
      if (!requireNamespace('digest'))
        stop('Must install package "digest" for this functionality', call. = FALSE) # nocov

      super$initialize('crc32c', configuration = list())
      private$.from <- 'bytes'
      private$.to <- 'bytes'
    },

    #' @description This method computes the CRC32C checksum of a data object
    #' and appends it to the data object.
    #' @param data The data whose checksum to compute.
    #' @return The input `data` object with the 32-bit checksum appended to it.
    encode = function(data) {
      dig <- writeBin(strtoi(digest::digest(data, 'crc32c', serialize = FALSE), base = 16L), raw())
      c(data, dig)
    },

    #' @description This method extracts the CRC32C checksum from the trailing
    #' 32-bits of a data object. It then computes the CRC32C checksum from the
    #' data object (less the trailing 32-bits) and compares the two values. If
    #' the values differ, a warning will be issued.
    #' @param data The data whose checksum to verify.
    #' @return The `data` object with the trailing 32-bits removed.
    decode = function(data) {
      len <- length(data)
      out <- data[1:(len - 4L)]
      chk_stored <- readBin(data[(len - 3L):len], 'integer')
      chk_calc <- strtoi(digest::digest(out, 'crc32c', serialize = FALSE), base = 16L)
      if (chk_stored != chk_calc)
        warning('Checksum failed on raw data object!', call. = FALSE) # nocov
      out
    }
  )
)
