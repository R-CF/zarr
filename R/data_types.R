#' Mapping Zarr v.3 core data_types to readBin() / writeBin() arguments
#' float16 and r* are not supported
zarr_v3_datatypes <- list(
  bool    = list(Rtype = 'logical',   size = 1L, signed = FALSE, fill_value = FALSE),
  int8    = list(Rtype = 'integer',   size = 1L, signed = TRUE,  fill_value = -127L),
  int16   = list(Rtype = 'integer',   size = 2L, signed = TRUE,  fill_value = -32767L),
  int32   = list(Rtype = 'integer',   size = 4L, signed = TRUE,  fill_value = -2147483647L),
  int64   = list(Rtype = 'integer64', size = 8L, signed = TRUE,  fill_value = NA), # Set in code
  uint8   = list(Rtype = 'integer',   size = 1L, signed = FALSE, fill_value = 255L),
  uint16  = list(Rtype = 'integer',   size = 2L, signed = FALSE, fill_value = 65535L),
  uint32  = list(Rtype = 'integer64', size = 4L, signed = FALSE, fill_value = NA), # Set in code
  uint64  = list(Rtype = 'double',    size = 8L, signed = FALSE, fill_value = 1.844674e+19),
  float32 = list(Rtype = 'double',    size = 4L, signed = TRUE,  fill_value = 9.9692099683868690e+36),
  float64 = list(Rtype = 'double',    size = 8L, signed = TRUE,  fill_value = 9.9692099683868690e+36)
  # complex64
  # complex128
)

#' Zarr data types
#'
#' @description This class implements a Zarr data type as an extension point.
#'   This class also manages the "fill_value" attribute associated with the data
#'   type.
#' @docType class
zarr_data_type <- R6::R6Class('zarr_data_type',
  inherit = zarr_extension,
  cloneable = FALSE,
  private = list(
    .data_type = '', # Zarr data type
    .Rtype = '',     # R data type for the Zarr data type
    .signed = TRUE,  # If the Zarr data type is signed or not
    .byte_size = 0L,
    .fill_value = NULL,

    set_type = function(data_type) {
      if (missing(data_type) || !is.character(data_type) || length(data_type) != 1L)
        stop('Data type name must be a single character string.', call. = FALSE) # nocov

      if (data_type %in% names(zarr_v3_datatypes)) {
        private$.data_type <- data_type
        private$.Rtype <- zarr_v3_datatypes[[data_type]]$Rtype
        private$.signed <- zarr_v3_datatypes[[data_type]]$signed
        private$.byte_size <- zarr_v3_datatypes[[data_type]]$size
        private$.fill_value <-
          switch(data_type,
                 'int64'  = bit64::as.integer64('9223372036854775807'),
                 'uint32' = bit64::as.integer64('4294967295'),
                 zarr_v3_datatypes[[data_type]]$fill_value)
      } else
        stop('Invalid data type for Zarr v.3: ', data_type, call. = FALSE) # nocov
    }
  ),
  public = list(
    #' @description Create a new data type object.
    #' @param data_type The name of the data type, a single character string.
    #' @param fill_value Optionally, the fill value for the data type.
    #' @return An instance of this class.
    initialize = function(data_type, fill_value = NULL) {
      if (data_type %in% c('int64', 'uint32') && !requireNamespace('bit64', quietly = TRUE))
        stop('Package "bit64" must be installed for this data type.', call. = FALSE) # nocov

      private$set_type(data_type)
      if (!is.null(fill_value))
        private$.fill_value <- fill_value
    },

    #' @description Print a summary of the data type to the console.
    print = function() {
      cat('<Zarr data type> ', private$.data_type,
          ' (', private$.byte_size, ' byte', if (private$.byte_size > 1L) 's',
          ' - fill value: ', private$.fill_value, ')\n', sep = '')
      invisible(self)
    },

    #' @description Return the metadata fragment for this data type and its fill
    #'   value.
    #' @return A list with the metadata fragment.
    metadata_fragment = function() {
      list(data_type = private$.data_type, fill_value = private$.fill_value)
    }
  ),
  active = list(
    #' @field data_type The data type for the Zarr array, a single character
    #'   string. Setting the data type will also set the fill value to its
    #'   default value.
    data_type = function(value) {
      if (missing(value))
        private$.data_type
      else {
        private$set_type(value)
      }
    },

    #' @field Rtype (read-only) The R data type corresponding to the Zarr data
    #'   type.
    Rtype = function(value) {
      if (missing(value))
        private$.Rtype
    },

    #' @field signed (read-only) Flag that indicates if the Zarr data type is
    #'   signed or not.
    signed = function(value) {
      if (missing(value))
        private$.signed
    },

    #' @field size (read-only) The size of the data type, in bytes.
    size = function(value) {
      if (missing(value))
        private$.byte_size
    },

    #' @field fill_value The fill value for the Zarr array, a single value that
    #'   agrees with the range of the `data_type`.
    fill_value = function(value) {
      if (missing(value))
        private$.fill_value
      else {
        # FIXME: Put in tests for domain of value
        private$.fill_value <- value
      }
    }
  )
)

# Parse a Zarr v.2 dtype string
zarr_v2_parse_dtype <- function(dtype) {
  m <- regexec("^([<>|])([ifubS])([0-9]+)$", dtype)
  parts <- regmatches(dtype, m)[[1L]]
  if (length(parts) == 0L)
    stop("Unsupported dtype string: ", dtype)

  endian <- switch(parts[2L],
                   "<" = "little",
                   ">" = "big",
                   "|" = "none")
  kind <- parts[3L]
  size <- as.integer(parts[4L])

  if (kind == "i" && size == 8L) {
    list(Rtype = "integer64", size = size, signed = TRUE, endian = endian)
  } else if (kind == "u" && size == 8L) {
    list(Rtype = "integer64", size = size, signed = FALSE, endian = endian)
  } else if (kind == "i") {
    list(Rtype = "integer", size = size, signed = TRUE, endian = endian)
  } else if (kind == "u") {
    list(Rtype = "integer", size = size, signed = FALSE, endian = endian)
  } else if (kind == "f") {
    list(Rtype = "numeric", size = size, endian = endian)
  } else if (kind == "b" && size == 1L) {
    list(Rtype = "logical", size = 1L, endian = NULL)
  } else if (kind == "S") {
    list(Rtype = "bytes", size = size, endian = NULL)
  } else
    NULL
}

