#' Array builder
#'
#' @description This class builds the metadata document for an array to be
#'   created or modified. It can also be used to inspect the metadata document
#'   of an existing Zarr array.
#'
#'   The Zarr core specification is quite complex for arrays, including codecs
#'   and storage transformers that are part optional, part mandatory, and
#'   dependent on each other. On top of that, extensions defined outside of the
#'   core specification must also be handled in the same metadata document. This
#'   class helps construct a valid metadata document, with support for (some)
#'   extensions. (If you need support for a specific extension, open an issue on
#'   Github.)
#'
#'   This class does not care about the "chunk_key_encoding" parameter. This is
#'   addressed at the level of the store.
#'
#'   The "codecs" parameter has a default first codec of "transpose". This
#'   ensures that R matrices and arrays can be stored in native column-major
#'   order with the store still accessible to environments that use row-major
#'   order by default, such as Python. A second default codec is "bytes" that
#'   records the endianness of the data. Other codecs may be added by the user,
#'   such as a compression codec.
#'
#'   This class only handles the mandatory attributes in a Zarr array metadata
#'   document. Optional arguments may be set directly on the Zarr array after it
#'   has been created.
#' @docType class
array_builder <- R6::R6Class('array_builder',
  cloneable = FALSE,
  private = list(
    # The metadata items managed by the instance
    .format = 3L,

    .data_type = NULL,
    .shape = NA,
    .chunk_shape = NULL,
    .codecs = list(),

    # Should the array have major portability?
    .portable = FALSE,

    # Compile the metadata items into a list that is Zarr array compatible
    build_metadata = function() {
      meta <- list(zarr_format = private$.format,
                   node_type = "array")
      if (!is.na(private$.shape[1L]))
        meta <- append(meta, list(shape = private$.shape))
      if (!is.null(private$.data_type))
        meta <- append(meta, private$.data_type$metadata_fragment())
      if (!is.null(private$.chunk_shape))
        meta <- append(meta, private$.chunk_shape$metadata_fragment())
      if (length(private$.codecs)) {
        codecs <- lapply(private$.codecs, function(cdc) cdc$metadata_fragment())
        meta <- append(meta, setNames(list(codecs), 'codecs'))
      }
      meta
    },

    # This method is called after the data_type or portability has been set to
    # update the list of codecs. Must have a data_type and a shape before any
    # codecs can be set.
    update_codecs = function() {
      if (!is.null(private$.data_type) && !is.na(private$.shape[1L])) {
        private$.codecs <- if (private$.portable || length(private$.shape) == 1L)
          # No transpose codec
          list(bytes = zarr_codec_bytes$new(private$.data_type, private$.chunk_shape$chunk_shape))
        else
          list(transpose = zarr_codec_transpose$new(length(private$.shape)),
               bytes = zarr_codec_bytes$new(private$.data_type, private$.chunk_shape$chunk_shape))
      } else
        private$.codecs <- list()
    }
  ),
  public = list(
    #' @description Create a new instance of the `array_builder` class.
    #'   Optionally, a metadata document may be passed in as an argument to
    #'   inspect the definition of an existing Zarr array, or to use as a
    #'   template for a new metadata document.
    #' @param metadata Optional. A JSON metadata document or list of metadata
    #'   from an existing Zarr array. This document will not be modified through
    #'   any operation in this class.
    #' @return An instance of this class.
    initialize = function(metadata = NULL) {
      if (!is.null(metadata)) {
        if (!is.list(metadata)) {
          meta <- try(jsonlite::fromJSON(metadata, simplifyDataFrame = FALSE), silent = TRUE)
          if (inherits(meta, "try-error")) {
            warning('Argument `metadata` is not a valid JSON document. Discarding.', call. = FALSE) # nocov
            meta <- list()
          }
        } else
          meta <- metadata

        if (length(meta)) {
          if (meta$zarr_format != 3)
            stop('Metadata document is not for a Zarr version 3 object.', call. = FALSE) # nocov
          self$format <- meta$zarr_format
          if (meta$node_type != 'array')
            stop('Metadata document is not for a Zarr array.', call. = FALSE) # nocov

          # Set properties through the active fields, checking is done there.
          self$shape <- meta$shape
          self$data_type <- meta$data_type
          self$fill_value <- meta$fill_value
          self$chunk_shape <- meta$chunk_grid$configuration$chunk_shape # regular grid only

          if (length(meta$codecs)) {
            private$.codecs <- list()
            lapply(meta$codecs, function(c) self$add_codec(c$name, c$configuration))
            names(private$.codecs) <- sapply(meta$codecs, function(c) c$name)
          }
        }
      }
    },

    #' @description Print the array metadata to the console.
    print = function() {
      cat('<Zarr array metadata>', if (self$is_valid()) 'VALID' else 'INCOMPLETE', '\n')
      meta <- private$build_metadata()
      cat(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE))
      invisible(self)
    },

    #' @description Retrieve the metadata document to create a Zarr array.
    #' @param format Either "list" or "JSON".
    #' @return The metadata document in the requested format.
    metadata = function(format = 'list') {
      format <- tolower(format)
      if (format == 'list')
        private$build_metadata()
      else if (format == 'json')
        jsonlite::toJSON(private$build_metadata(), auto_unbox = TRUE, pretty = TRUE)
      else
        stop('Bad format for Zarr metadata.', call. = FALSE) # nocov
    },

    #' @description Adds a codec at the end of the currently registered codecs.
    #'   Optionally, the `.position` argument may be used to indicate a specific
    #'   position of the codec in the list. Codecs can only be added if their
    #'   mode agrees with the mode of existing codecs - if this codec does not
    #'   agree with the existing codecs, a warning will be issued and the new
    #'   codec will not be registered.
    #' @param codec The name of the codec. This must be a registered codec with
    #'   an implementation that is available from this package.
    #' @param configuration List with configuration parameters of the `codec`.
    #'   May be `NULL` or `list()` for codecs that do not have configuration
    #'   parameters.
    #' @param .position Optional, the 1-based position where to insert the codec
    #'   in the list. If the number is larger than the list, the codec will be
    #'   appended at the end of the list of codecs.
    #' @return Self, invisibly.
    add_codec = function(codec, configuration, .position = NULL) {
      if (is.null(private$.data_type) || is.na(private$.shape[1L]))
        stop('Codecs can only be added after the array data_type and shape have been set.', call. = FALSE) # nocov

      if (!is.character(codec) || length(codec) != 1L)
        stop('Codec name must be a single character string.', call. = FALSE) # nocov

      cdc <- switch(codec,
                    'transpose' = zarr_codec_transpose$new(length(private$.shape), configuration),
                    'bytes' = zarr_codec_bytes$new(private$.data_type, private$.chunk_shape$chunk_shape, configuration),
                    'blosc' = zarr_codec_blosc$new(data_type = private$.data_type, configuration),
                    'zstd' = zarr_codec_zstd$new(configuration),
                    'gzip' = zarr_codec_gzip$new(configuration),
                    'crc32c' = zarr_codec_crc32c$new())
      if (!inherits(cdc, 'zarr_codec'))
        stop('Could not create a codec from the arguments:', codec, call. = FALSE) # nocov

      len <- length(private$.codecs)
      if (is.null(.position) || .position > len) {
        if (!len) {
          if (cdc$from == 'array')
            private$.codecs <- setNames(list(cdc), cdc$name)
          else
            stop('Codec has incompatible mode to start chains of codecs.', call. = FALSE) #nocov
        } else if (cdc$from == private$.codecs[[len]]$to)
          private$.codecs <- c(private$.codecs, setNames(list(cdc), cdc$name))
        else
          stop('Codec has incompatible mode to follow previous codec.', call. = FALSE) #nocov
      } else if (.position == 1) {
        if (cdc$from == 'array' && private$.codecs[[1L]]$from == cdc$to)
          private$.codecs <- c(setNames(list(cdc), cdc$name), private$.codecs)
        else
          stop('First codec must use an "array" mode for input and agree with the following codec.', call. = FALSE) # nocov
      } else if (cdc$from == private$.codecs[[len - 1L]]$to && cdc$to == private$.codecs[[len]]$from)
        private$.codecs <- append(private$.codecs, setNames(list(cdc), cdc$name), after = len - 1L)
      else
        stop('Codec has incompatible mode for inserting at position ', .position, call. = FALSE) # nocov

      invisible(self)
    },

    #' @description Remove a codec from the list of codecs for the array. A
    #' codec cannot be removed if the remaining codecs do not form a valid
    #' chain due to mode conflicts.
    #' @param codec The name of the codec to remove, a single character string.
    remove_codec = function(codec) {
      ndx <- which(sapply(private$.codecs, function(cdc) cdc$name) == codec)
      if (length(ndx)) {
        tst <- private$.codecs[-ndx]
        if (len <- length(tst)) {
          froms <- sapply(tst, function(t) t$from)
          tos <- sapply(tst, function(t) t$to)
          if (froms[1L] == 'array' && tos[len] == 'bytes' && all(froms[-1L] == tos[-len]))
            private$.codecs <- tst
          else
            stop('Cannot remove codec as it will invalidate the codec list.', call. = FALSE) # nocov
        } else
          private$.codecs <- list()
      }
      invisible(self)
    },

    #' @description This method indicates if the current specification results
    #'   in a valid metadata document to create a Zarr array.
    #' @return `TRUE` if a valid metadata document can be generated, `FALSE`
    #'   otherwise.
    is_valid = function() {
      !is.null(private$.data_type) &&
      !is.na(private$.shape[1L]) &&
      !is.null(private$.chunk_shape) &&
      length(private$.codecs)
    }
  ),
  active = list(
    #' @field format The Zarr format to build the metadata for. The value must
    #'   be 3. After changing the format, many fields will have been reset to a
    #'   default value.
    format = function(value) {
      if (missing(value))
        private$.format
      else if (is.numeric(value)) {
        value <- as.integer(value[1L])
        if ((value == 2L || value == 3L) && private$.format != value) {
          private$.format <- value
          private$.data_type <- NULL
        }
      }
    },

    #' @field portable Logical flag to indicate if the array is specified for
    #'   maximum portability across environments (e.g. Python, Java, C++).
    #'   Default is `FALSE`. Setting the portability to `TRUE` implies that R
    #'   data will be permuted before writing the array to the store. A value of
    #'   `FALSE` is therefore more efficient.
    portable = function(value) {
      if (missing(value))
        private$.portable
      else if (is.logical(value) && length(value) == 1L) {
        private$.portable <- value
        private$update_codecs()
      } else
        stop('The portable property must be set with a single logical value.', call. = FALSE) # nocov
    },

    #' @field data_type The data type of the Zarr array. After changing the
    #'   format, many fields will have been reset to a default value.
    data_type = function(value) {
      if (missing(value))
        private$.data_type
      else if (is.null(private$.data_type)) {
        private$.data_type <- zarr_data_type$new(value)
        private$update_codecs()
      } else {
        if (private$.data_type$data_type != value) {
          private$.data_type$data_type <- value
          private$update_codecs()
        }
      }
    },

    #' @field fill_value The value in the array of uninitialized data elements.
    #' The `fill_value` has to agree with the `data_type` of the array.
    fill_value = function(value) {
      if (missing(value))
        private$.data_type$fill_value
      else
        private$.data_type$fill_value <- value
    },

    #' @field shape The shape of the Zarr array, an integer vector of lengths
    #' along the dimensions of the array. Setting the shape will reset the
    #' chunking settings to their default values.
    shape = function(value) {
      if (missing(value))
        private$.shape
      else {
        if (is.numeric(value) && all((value <- as.integer(value)) > 0L)) {
          private$.shape <- value
          private$.chunk_shape <- chunk_grid_regular$new(value, pmin.int(value, Zarr.options$chunk_length))
          private$update_codecs()
        } else
          stop('Shape must be an integer vector of lengths along each dimension of the Zarr array.', call. = FALSE) # nocov
      }
    },

    #' @field chunk_shape The shape of each individual chunk in which to store
    #'   the Zarr array. When setting, pass in an integer vector of lengths of
    #'   the same size as the shape of the array. The `shape` of the array must
    #'   be set before setting this. When reading, returns an instance of class
    #'   [chunk_grid_regular].
    chunk_shape = function(value) {
      if (missing(value))
        private$.chunk_shape
      else
        private$.chunk_shape <- chunk_grid_regular$new(private$.shape, as.integer(value))
    },

    #' @field codec_info (read-only) Retrieve a `data.frame` of registered codec
    #' modes and names for this array.
    codec_info = function(value) {
      if (missing(value)) {
        if (length(private$.codecs))
          do.call(rbind, lapply(private$.codecs, function(cod) data.frame(mode = cod$mode(), codec = cod$name)))
      }
    },

    #' @field codecs (read-only) A list with validated and instantiated codecs
    #'   for processing data associated with this array.
    codecs = function(value) {
      if (missing(value))
        private$.codecs
    }
  )
)
