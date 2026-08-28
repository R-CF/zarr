#' Zarr Array
#'
#' @description This class implements a Zarr array. A Zarr array is stored in a
#'   node in the hierarchy of a Zarr data set. The array contains the data for
#'   an object.
#' @docType class
#' @export
zarr_array <- R6::R6Class('zarr_array',
  inherit = zarr_node,
  cloneable = FALSE,
  private = list(
    # The data type of the array, a zarr_data_type instance
    .data_type = NULL,

    # An instance of `chunk_grid_regular` to manage data chunking and I/O.
    .chunking = NULL,

    # The glyph used for depicting an array when printing. Descendant classes
    # may override this to more easily identify different classes of arrays.
    .glyph = '\u2317',

    # Returns a list with pre, sep and scalar elements that describe the
    # chunk key encoding of the array.
    chunk_key_encoding = function() {
      if (private$.metadata$zarr_format == 2L) {
        list(pre = '',
             sep = private$.metadata$dimension_separator %||% '.',
             scalar = '0')
      } else {
        if (private$.metadata$chunk_key_encoding$name == 'default')
          list(pre = paste0('c', private$.metadata$chunk_key_encoding$configuration$separator),
               sep = private$.metadata$chunk_key_encoding$configuration$separator %||% '/',
               scalar = 'c')
        else # v2
          list(pre = '',
               sep = private$.metadata$chunk_key_encoding$configuration$separator %||% '.',
               scalar = '0')
      }
    }
  ),
  public = list(
    #' @description Initialize a new array in a Zarr hierarchy. The array must
    #'   already exist in the store
    #' @param name The name of the array.
    #' @param metadata List with the metadata of the array.
    #' @param parent The parent `zarr_group` instance of this new array, can be
    #'   missing or `NULL` if the Zarr object should have just this array.
    #' @param store The [zarr_store] instance to persist data in. Ignored if
    #'   `parent` is specified.
    #' @return An instance of `zarr_array`.
    initialize = function(name, metadata, parent, store) {
      ab <- array_builder$new(metadata)
      if (!ab$is_valid())
        stop('Invalid metadata for an array.', call. = FALSE) # nocov

      super$initialize(name, metadata, parent, store)
      private$.data_type <- ab$data_type
      private$.chunking <- ab$chunk_shape
      private$.chunking$data_type <- private$.data_type
      private$.chunking$store <- store
      private$.chunking$array_prefix <- self$prefix
      private$.chunking$codecs <- ab$codecs
      private$.chunking$chunk_encoding <- private$chunk_key_encoding()
    },

    #' @description Print a summary of the array to the console.
    print = function() {
      meta <- private$.metadata
      cat('<Zarr array>', private$.glyph, private$.name, '\n')
      cat('Path      :', self$path, '\n')
      if (nzchar(private$.domain))
        cat('Domain    :', private$.domain, '\n')
      cat('Data type :', private$.data_type$data_type, '\n')
      shp <- meta$shape
      if (length(shp)) {
        cat('Shape     :', shp)
        dim_names <- meta$dimension_names %||% meta$attributes$`_ARRAY_DIMENSIONS`
        if (is.null(dim_names)) cat('\n')
        else cat(' [', paste(dim_names, collapse = ', '), ']\n', sep = '')
        cat('Chunking  :', meta$chunk_grid$configuration$chunk_shape, '\n')
      } else {
        cat('Shape     : (scalar)\n')
        cat('Chunking  : (scalar)\n')
      }
      private$print_details()
      self$print_attributes()
      invisible(self)
    },

    #' @description Prints the hierarchy of this array to a character string.
    #'   Usually called from the Zarr object or a group to display the full
    #'   group hierarchy.
    #' @param idx,total Arguments to control indentation.
    hierarchy_nodes = function(idx, total) {
      if (!nzchar(private$.name))
        paste(private$.glyph, '(root array)\n')
      else {
        knot <- if (idx == total) '\u2514 ' else '\u251C '
        paste0(knot, private$.glyph, ' ', private$.name, '\n')
      }
    },

    #' @description Read some or all of the array data for the array. For all
    #'   types other than logical, any data elements with the `fill_value` of
    #'   the Zarr data type are set to `NA`.
    #' @param selection A list as long as the array has dimensions where each
    #'   element is a range of indices along the dimension to read. If missing
    #'   or `NULL`, the entire array will be read.
    #' @return A vector, matrix or array of data.
    read = function(selection) {
      array_shape <- private$.metadata$shape
      if (missing(selection) || is.null(selection))
        selection <- lapply(array_shape, function(d) c(1L, d))
      if (length(selection) == length(array_shape)) {
        start <- sapply(selection, min)
        stop  <- sapply(selection, max)
        if (any(start < 1L | start > array_shape | stop > array_shape))
          stop('Array selection indices are out of bounds.', call. = FALSE) # nocov
        data <- private$.chunking$read(start, stop)

        fill <- private$.data_type$fill_value
        Rtype <- private$.data_type$Rtype
        if (is.nan(fill))
          data[which(is.nan(data))] <- NA
        else if (Rtype == 'integer')
          data[data == fill] <- NA
        else if (!(Rtype %in% c('logical', 'integer64', 'character'))) # FIXME: is.na(integer64)??
          data[.near(data, fill)] <- NA
      } else
        stop('`selection` list must have the same length as the shape of the array.', call. = FALSE) # nocov

      data
    },

    #' @description Write data for the array. The data will be chunked, encoded
    #'   and persisted in the store that the array is using. Prior to writing,
    #'   any `NA` values are assigned the `fill_value` of the array. Note that
    #'   the logical type cannot encode `NA` in Zarr and any `NA` values are set
    #'   to `FALSE`.
    #' @param data An R vector, matrix or array with the data to write. The data
    #'   in the R object has to agree with the data type and rank of the array.
    #' @param selection Optional. A `list` as long as the array has dimensions
    #'   where each element is a range of indices along the dimension to write.
    #'   If missing, the `data` object must have the same size as the array.
    #'   Ignored when the array is scalar.
    #' @return Self, invisibly.
    write = function(data, selection) {
      if (storage.mode(data) != private$.data_type$Rtype)
        stop('Data is of a different type than the array', call. = FALSE) # nocov

      ddim <- dim(data) %||% length(data)
      ndata <- length(ddim)

      array_shape <- private$.metadata$shape
      if (!length(array_shape)) { # Scalar array
        if (ndata == 1L && ddim == 1L) {
          private$.chunking$write(data)
          return(invisible(self))
        } else
          stop('Writing to a scalar array can include only a single value as `data`', call. = FALSE)
      }

      if (missing(selection))
        selection <- lapply(ddim, function(d) c(1L, d))
      nsel <- length(selection)
      if (nsel != length(array_shape))
        stop('`selection` list must have the same length as the shape of the array', call. = FALSE) # nocov
      start <- sapply(selection, min)
      stop  <- sapply(selection, max)
      sdim  <- stop - start + 1L

      if (nsel < ndata)
        stop("Data has higher rank than the selection indices", call. = FALSE) # nocov
      if (!(nsel == ndata && all(ddim == sdim))) {
        # Broadcast `data` to selection dimensions
        ddim <- c(rep(1L, nsel - ndata), ddim)
        if (any(!(ddim == sdim | ddim == 1L)))
          stop("Cannot broadcast data to selection dimensions", call. = FALSE) # nocov
        data <- array(data, dim = ddim)
        if ((proddim <- prod(sdim)) != prod(ddim))
          data <- array(rep(data, each = proddim), dim = sdim)
      }
      dt <- private$.data_type
      data[is.na(data)] <- dt$fill_value
      private$.chunking$write(data, start, stop)

      invisible(self)
    },

    #' @description Resize the array, growing or shrinking any combination of
    #'   dimensions at either end in one pass. Existing chunk payload is never
    #'   rewritten, except for a chunk left straddling a shrinking, non-chunk-
    #'   aligned high-end boundary (its excess elements become `NA`).
    #'
    #'   Because the chunk grid is fixed, `low` can only move in whole chunks:
    #'   values are rounded outward to the nearest chunk (more space added
    #'   when growing, less removed when shrinking), so the array's origin
    #'   may land ahead of where the actual data starts; those cells read as
    #'   `NA`. `high` is not constrained this way.
    #' @param low,high Integer vectors, one element per array dimension.
    #'   Positive grows that end, negative shrinks it, `0` (default) leaves
    #'   it unchanged.
    #' @return Self, invisibly.
    resize = function(low, high) {
      shape <- private$.metadata$shape
      nd <- length(shape)
      if (!nd) stop('Cannot resize a scalar array; see `promote()`.', call. = FALSE)
      if (missing(low))  low  <- integer(nd)
      if (missing(high)) high <- integer(nd)
      if (length(low) != nd || length(high) != nd)
        stop('`low` and `high` must have one element per dimension of the array.', call. = FALSE)

      chunk_shape <- private$.chunking$chunk_shape
      shift <- ifelse(low >= 0L, ceiling(low / chunk_shape), -floor(-low / chunk_shape))
      new_shape <- as.integer(shape + shift * chunk_shape + high)
      if (any(new_shape < 1L))
        stop('Resizing would produce a non-positive extent along one or more dimensions.', call. = FALSE)

      private$.chunking$resize(new_shape, as.integer(shift), high)
      private$.metadata$shape <- new_shape
      private$.meta_dirty <- TRUE
      self$save()
      invisible(self)
    },

    #' @description Insert a new dimension into the array, increasing its
    #'   rank by one. This operation doesn't
    #'   grow an existing dimension, it creates one where there wasn't one before
    #'   — the typical case being promoting a 0-d scalar array to rank 1, or
    #'   giving an existing array a new leading dimension (e.g. turning a
    #'   `(lat, lon)` array into a `(time, lat, lon)` array once a second
    #'   file/time step becomes available).
    #'
    #'   Existing chunk payload is moved, never re-encoded: inserting a
    #'   size-`length` dimension whose chunk size equals `length` never changes
    #'   the relative order of elements in the encoded byte stream, for any
    #'   array rank or transpose order, because a size-1-chunk dimension never
    #'   contributes more than a single (vacuous) index to the enumeration.
    #'   So every existing chunk is just renamed with a "0" grid index
    #'   inserted at `dimension`. The new dimension therefore always starts out as
    #'   exactly one full chunk; grow it afterwards with `resize()`.
    #' @param dimension Integer. 1-based position of the new dimension in the
    #'   resulting shape; `1` prepends it, `rank + 1` appends it.
    #' @param length The size of the new dimension, and also its chunk size.
    #'   Default `1L`.
    #' @return Self, invisibly.
    promote = function(dimension, length = 1L) {
      if (inherits(private$.chunking, 'chunk_grid_sharded'))
        stop('`promote()` is not supported for sharded arrays', call. = FALSE)

      old_shape <- private$.metadata$shape
      old_chunk <- private$.chunking$chunk_shape
      r <- length(old_shape)
      if (dimension < 1L || dimension > r + 1L)
        stop('`dimension` must be between 1 and ', r + 1L, ' for an array of rank ', r, call. = FALSE)
      if (length < 1L)
        stop('`length` must be a positive integer', call. = FALSE)

      if (r == 0L) {
        new_shape <- as.integer(length)
        new_chunk <- as.integer(length)
      } else {
        new_shape <- append(as.integer(old_shape), as.integer(length), after = dimension - 1L)
        new_chunk <- append(as.integer(old_chunk), as.integer(length), after = dimension - 1L)
      }

      ab <- array_builder$new()
      ab$data_type   <- private$.data_type$data_type
      ab$fill_value  <- private$.data_type$fill_value
      ab$shape       <- new_shape
      ab$chunk_shape <- new_chunk
      for (cdc in private$.chunking$codecs) {
        if (!(cdc$name %in% c('transpose', 'bytes', 'vlen-utf8', 'ucs-4'))) {
          frag <- cdc$metadata_fragment()
          ab$add_codec(frag$name, frag$configuration)
        }
      }

      new_meta <- ab$metadata()
      if (length(private$.metadata$attributes))
        new_meta$attributes <- private$.metadata$attributes
      # Note: any existing `dimension_names` is deliberately dropped here —
      # its length no longer matches the new rank. Set a fresh one via
      # set_attribute()/the dedicated field once the new axis has a name.

      cke <- private$chunk_key_encoding()
      if (r == 0L) {
        scalar_key <- paste0(self$prefix, cke$scalar)
        chunk_key  <- paste0(self$prefix, cke$pre, '0')
        if (private$.store$exists(scalar_key))
          private$.store$rename(scalar_key, chunk_key)
      } else {
        keys <- private$.store$list_chunks(self$prefix)
        lead <- paste0(self$prefix, cke$pre)
        for (old_key in keys) {
          cidx     <- as.integer(strsplit(substring(old_key, nchar(lead) + 1L), cke$sep, fixed = TRUE)[[1L]])
          new_cidx <- append(cidx, 0L, after = dimension - 1L)
          new_key  <- paste0(lead, paste(new_cidx, collapse = cke$sep))
          if (old_key != new_key) private$.store$rename(old_key, new_key)
        }
      }

      private$.store$set_metadata(self$prefix, new_meta)

      # Rebuild live objects from the persisted metadata, exactly as
      # zarr_array$initialize() does for a freshly opened array. Necessary
      # because array_builder's chunk_shape<- setter doesn't refresh any
      # codec already built against the transient auto-chunk shape from
      # when shape<- ran above.
      ab2 <- array_builder$new(new_meta)
      private$.metadata  <- new_meta
      private$.data_type <- ab2$data_type
      private$.chunking  <- ab2$chunk_shape
      private$.chunking$data_type      <- private$.data_type
      private$.chunking$store          <- private$.store
      private$.chunking$array_prefix   <- self$prefix
      private$.chunking$codecs         <- ab2$codecs
      private$.chunking$chunk_encoding <- cke

      invisible(self)
    }
  ),
  active = list(
    #' @field data_type (read-only) Retrieve the data type of the array.
    data_type = function(value) {
      if (missing(value))
        private$.data_type
    },

    #' @field shape (read-only) Retrieve the shape of the array, an integer
    #'   vector.
    shape = function(value) {
      if (missing(value))
        private$.metadata$shape
    },

    #' @field chunking (read-only) The chunking engine for this array.
    chunking = function(value) {
      if (missing(value))
        private$.chunking
    },

    #' @field chunk_separator (read-only) Retrieve the separator to be used for
    #' creating store keys for chunks.
    chunk_separator = function(value) {
      if (missing(value))
        private$.metadata$chunk_key_encoding$configuration$separator
    },

    #' @field codecs The list of codecs that this array uses for encoding data
    #' (and decoding in inverse order).
    codecs = function(value) {
      if (missing(value))
        private$.chunking$codecs
    }
  )
)

# --- S3 functions ---
#' Compact display of a Zarr array
#' @param object A `zarr_array` instance.
#' @param ... Ignored.
#' @export
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' tas <- africa[["/tas"]]
#' str(tas)
str.zarr_array <- function(object, ...) {
  cat('Zarr array: [', object$data_type$data_type, '] shape [',
      paste(object$shape, collapse = ', '), '] chunk [',
      paste(object$chunking$chunk_shape, collapse = ', '), ']', sep = '')
}

#' Extract or replace parts of a Zarr array
#'
#' These operators can be used to extract or replace data from an array by
#' indices. Normal R array selection rules apply. The only limitation is that
#' the indices have to be consecutive.
#'
#' @param x A `zarr_array` object of which to extract or replace the data.
#' @param i,j,... Indices specifying elements to extract or replace. Indices are
#'   numeric, empty (missing) or `NULL`. Numeric values are coerced to integer.
#'   The number of indices has to agree with the dimensionality of the array.
#' @param drop If `TRUE` (the default), degenerate dimensions are dropped, if
#'   `FALSE` they are retained in the result.
#' @return When extracting data, a vector, matrix or array, having dimensions as
#'   specified in the indices.
#' @name array-indexing
#' @export
#' @docType methods
#' @examples
#' x <- array(1:100, c(10, 10))
#' z <- as_zarr(x)
#' arr <- z[["/"]]
#' arr[3:5, 7:9]
"[.zarr_array" <- function(x, i, j, ..., drop = TRUE) {
  caller_env <- parent.frame()

  sc <- sys.call()
  args <- sc[-(1:2)]      # remove function name and x
  args$drop <- NULL       # remove drop if present

  if ((length(args) == 1L) && (identical(args[[1L]], quote(expr = ))))
    selection <- NULL
  else {
    # Replace missing indices with NULL
    indices <- lapply(args, function(arg) {
      if (is.symbol(arg) && identical(arg, quote(expr = )))
        NULL
      else
        eval(arg, caller_env)
    })

    nd <- length(x$shape)
    if (length(indices) != nd)
      stop('Invalid number of selection indices for the array.', call. = FALSE) # nocov
    selection <- vector("list", nd)

    for (d in seq_len(nd)) {
      if (is.null(indices[[d]])) {
        # Missing index
        selection[[d]] <- c(1L, x$shape[d])
      } else {
        sel <- indices[[d]]
        if (is.logical(sel))
          sel <- which(sel)
        else if (any(sel < 0L))
          sel <- setdiff(seq_len(x$shape[d]), abs(sel))
        selection[[d]] <- range(sel)
      }
    }
  }

  data <- x$read(selection)
  if (drop) drop(data) else data
}
