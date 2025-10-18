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
    # The input and output data object for the encoding operation
    .from = 'array',
    .to   = 'bytes'
  ),
  public = list(
    #' @description Create a new codec object.
    #' @param name The name of the codec, a single character string.
    #' @return An instance of this class.
    initialize = function(name) {
      super$initialize(name)
    },

    #' @description This method gives the operating mode of the encoding
    #'   operation of the codec in form of a string "array -> array", "array ->
    #'   bytes" or "bytes -> bytes".
    mode = function() {
      paste(private$.from, private$.to, sep = ' -> ')
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
  private = list(
    # The order of the dimensions, 0-based, relative to the Zarr canonical
    # dimension ordering.
    .order = NULL
  ),
  public = list(
    #' @description Create a new "transpose" codec object.
    #' @param shape The shape of the array that this codec operates on.
    #' @param order Optional. The ordering of the dimensions of the shape
    #'   relative to the Zarr canonical arrangement. An integer vector with a
    #'   length equal to the dimensions of argument `shape`. The ordering must
    #'   be 0-based. If not given, the default R ordering is used.
    #' @return An instance of this class.
    initialize = function(shape, order = NULL) {
      super$initialize('transpose')
      private$.from <- 'array'
      private$.to <- 'array'

      shape_len <- length(shape)
      if (shape_len < 2L)
        stop('Can only set a transpose codec on a matrix or array.', call. = FALSE) # nocov

      if (is.null(order))
        private$.order <- seq(shape_len - 1L, 0L, -1L)
      else if (shape_len == length(order) && all(order %in% (seq(shape_len) - 1L)))
        private$.order <- as.integer(order)
      else
        stop('Dimension ordering does not match the shape.', call. = FALSE) # nocov
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      list(name = 'transpose',
           configuration = list(order = private$.order))
    },

    #' @description This method permutes a data object to match the desired
    #' dimension ordering.
    #' @param data The data to be permuted, an R matrix or array.
    #' @return The permuted data object, a matrix or array in Zarr store
    #' dimension order.
    encode = function(data) {
      if (all(diff(private$.order) == -1L))
        # Store in native R order - no-op
        data
      else
        aperm(data, perm = rev(private$.order) + 1L)
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
        aperm(data, perm = rev(private$.order) + 1L)
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
    .dtype = NULL,

    # The endianness of the data when written to a store.
    .endian = ''
  ),
  public = list(
    #' @description Create a new "bytes" codec object.
    #' @param data_type The [zarr_data_type] instance of the Zarr array that
    #'   this codec is used for.
    #' @param endian Optional. The endianness of the data storage, either "big"
    #' or "little". The default value is the endianness of the platform that the
    #' R session is running on.
    #' @return An instance of this class.
    initialize = function(data_type, endian = .Platform$endian) {
      super$initialize('bytes')
      private$.from <- 'array'
      private$.to <- 'bytes'
      if (length(endian) == 1L && endian %in% c("big", "little"))
        private$.endian <- endian
      else
        stop('Bad value for endianness of the data.', call. = FALSE) # nocov
      if (inherits(data_type, 'zarr_data_type'))
        private$.dtype <- data_type
      else
        stop('Codec must be initialized with a `zarr_data_type` instance.', call. = FALSE) # nocov
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      if (private$.dtype$size > 1L)
        list(name = 'bytes',
             configuration = list(endian = private$.endian))
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
      dt <- private$.dtype
      data[is.na(data)] <- dt$fill_value

      if (dt$data_type == 'logical') {
        as.raw(as.integer(data))
      } else if (dt$data_type == 'integer64') {
        writeBin(unclass(data), raw(), endian = private$.endian)
      } else
        writeBin(data, raw(), size = dt$size, endian = private$.endian)
    },

    #' @description This method takes a raw vector and converts it to an R
    #' object of an appropriate type. For all types other than logical, any
    #' data elements with the `fill_value` of the Zarr data type are set to
    #' `NA`.
    #' @param data The data to be decoded.
    #' @return An R object with the shape of a chunk from the array.
    decode = function(data) {
      dt <- private$.dtype
      n <- length(data) %/% dt$size
      if (n %% dt$size)
        stop('Data length not a multiple of data type size.', call. = FALSE) # nocov

      out <- if (dt$data_type == 'logical') {
        as.logical(as.integer(data))
      } else if (dt$data_type == 'integer64') {
        vals <- readBin(data, what = 'double', n = n, endian = private$.endian)
        class(vals) <- 'integer64'
        vals
      } else {
        readBin(data, what = dt$Rtype, size = dt$size, signed = dt$signed,
                n = n, endian = private$.endian)
      }

      if (dt$data_type != 'logical')
        out[out == dt$fill_value] <- NA

      out
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
    .cname = '',
    .clevel = 6L,
    .shuffle = "noshuffle",
    .typesize = 1L
  ),
  public = list(
    #' @description Create a new "blosc" codec object. The typesize argument is
    #'   taken from the data type of the array passed in through the `data_type`
    #'   argument and the shuffle argument is chosen based on the `data_type`.
    #' @param data_type The [zarr_data_type] instance of the Zarr array that
    #'   this codec is used for.
    #' @param cname Optional. Character string with the name of the compression
    #'   engine, either "blosclz", "lz4", "lz4hc", "zstd" or "zlib". Default is
    #'   "zlib".
    #' @param clevel Optional. Compression level, a single integer value between
    #'   0L (no compression) and 9L (maximum compression). Default is 6L.
    #' @return An instance of this class.
    initialize = function(data_type, cname = 'zlib', clevel = 6L) {
      if (!requireNamespace('blosc'))
        stop('Must install package "blosc" for this functionality', call. = FALSE) # nocov

      super$initialize('blosc')
      if (is.character(cname) && length(cname) == 1L &&
          cname %in% c("blosclz", "lz4", "lz4hc", "zstd", "zlib"))
        private$.cname <- cname
      else
        stop('Invalid compression name:', cname, call. = FALSE) # nocov

      if (is.numeric(clevel) && length(clevel) == 1L && (clevel >= 0) && (clevel <= 9))
        private$.clevel <- as.integer(clevel)
      else
        stop('Argument clevel must be a single integer value between 0 and 9.', call. = FALSE) # nocov

      if (inherits(data_type, 'zarr_data_type')) {
        private$.typesize <- data_type$size
        private$.shuffle <-
          if (data_type$data_type %in% c('bool', 'int8', 'uint8')) 'noshuffle'
          else if (data_type$data_type %in% c('int16', 'uint16', 'int32', 'uint32', 'int64', 'float32')) 'shuffle'
          else 'bitshuffle'
      } else
        stop('Codec must be initialized with a `zarr_data_type` instance.', call. = FALSE) # nocov

      private$.from <- 'bytes'
      private$.to <- 'bytes'
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      list(name = 'blosc',
           configuration = list(cname = private$.cname,
                                clevel = private$.clevel,
                                shuffle = private$.shuffle,
                                typesize = private$.typesize,
                                blocksize = 0L))
    },

    #' @description This method compresses a data object using the "blosc"
    #' compression library.
    #' @param data The raw vector to be compressed.
    #' @return A raw vector with compressed data.
    encode = function(data) {
      if (is.raw(data))
        blosc::blosc_compress(data, compressor = private$.cname, level = private$.clevel,
                              shuffle = private$.shuffle, typesize = private$.typesize)
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
  private = list(
    .level = 6L
  ),
  public = list(
    #' @description Create a new "gzip" codec object.
    #' @param level Optional. Compression level, a single integer value between
    #'   0L (no compression) and 9L (maximum compression). Default is 6L.
    #' @return An instance of this class.
    initialize = function(level = 6L) {
      if (!requireNamespace('zlib'))
        stop('Must install package "zlib" for this functionality', call. = FALSE) # nocov

      super$initialize('gzip')
      if (is.numeric(level) && length(level) == 1L && (level >= 0) && (level <= 9))
        private$.level <- as.integer(level)
      else
        stop('Argument level must be a single integer value between 0 and 9.', call. = FALSE) # nocov

      private$.from <- 'bytes'
      private$.to <- 'bytes'
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      list(name = 'gzip',
           configuration = list(level = private$.level))
    },

    #' @description This method encodes a data object.
    #' @param data The data to be encoded.
    #' @return The encoded data object.
    encode = function(data) {
      zlib::compress(data, level = private$.level, wbits = 31)
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
        private$.level
      else if (is.numeric(value) && length(value) == 1L && value >= 0 && value <= 9) {
        private$.level <- as.integer(value)
      } else
        stop('Compression level of gzip must be an integer value between 0 and 9.', call. = FALSE) # nocov
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
    #' @return An instance of this class.
    initialize = function() {
      if (!requireNamespace('digest'))
        stop('Must install package "digest" for this functionality', call. = FALSE) # nocov

      super$initialize('crc32c')
      private$.from <- 'bytes'
      private$.to <- 'bytes'
    },

    #' @description Return the metadata fragment that describes this codec.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      list(name = 'crc32c')
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
