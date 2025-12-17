#' Chunk management
#'
#' @description This class implements the regular chunk grid for Zarr
#'   arrays. It manages reading from and writing to Zarr stores, using the
#'   codecs for data transformation.
#' @docType class
chunk_grid_regular <- R6::R6Class('chunk_grid_regular',
  inherit = zarr_extension,
  cloneable = FALSE,
  private = list(
    # The shape of the array and the chunk grid.
    .array_shape = NULL,
    .chunk_shape = NULL,

    # The chunk grid, calculated from the array and chunk shapes
    .chunk_grid = NULL,

    # Map of [chunk_id] -> chunk_grid_regular_IO instance
    .chunk_map = NULL,
    .chunk_sep = '/',

    # The underlying properties of the array
    .data_type = NULL,
    .codecs = list(),
    .store = NULL,
    .array_prefix = ''
  ),
  public = list(
    #' @description Initialize a new chunking scheme for an array.
    #' @param array_shape Integer vector of the array dimensions.
    #' @param chunk_shape Integer vector of the dimensions of each chunk.
    #' @return An instance of `chunk_grid_regular`.
    initialize = function(array_shape, chunk_shape) {
      super$initialize('regular')

      if (is.integer(array_shape) && all(array_shape > 0L))
        private$.array_shape <- array_shape
      else
        stop('Array shape must be defined using integer vector of positive values.', call. = FALSE) # nocov

      if (is.integer(chunk_shape) && all(chunk_shape > 0L) && length(array_shape) == length(chunk_shape))
        private$.chunk_shape <- chunk_shape
      else
        stop('Chunk shape is not valid for `array_shape`.', call. = FALSE) # nocov

      private$.chunk_grid <- ceiling(array_shape / chunk_shape)
      private$.chunk_map <- new.env(parent = emptyenv())
    },

    #' @description Print a short description of this chunking scheme to the
    #'   console.
    #' @return Self, invisibly.
    print = function() {
      cat('<Zarr regular chunk grid> [', paste(private$.chunk_shape, collapse = ', '), ']\n', sep = '')
      invisible(self)
    },

    #' @description Return the metadata fragment that describes this chunking
    #'   scheme.
    #' @return A list with the metadata of this codec.
    metadata_fragment = function() {
      list(chunk_grid = list(name = 'regular',
                             configuration = list(chunk_shape = private$.chunk_shape)))
    },

    #' @description Read data from the Zarr array into an R object.
    #' @param start,stop Integer vectors of the same length as the
    #'   dimensionality of the Zarr array, indicating the starting and ending
    #'   (inclusive) indices of the data along each axis.
    #' @return A vector, matrix or array of data.
    read = function(start, stop) {
      chunk_shape  <- private$.chunk_shape
      nd <- length(chunk_shape)
      data <- if (nd == 1L) vector(private$.data_type$Rtype, stop - start + 1L)
              else array(private$.data_type$fill_value, stop - start + 1L)
      sep <- private$.chunk_sep
      chunk_pre <- if (private$.store$version == 3L) paste0('c', sep) else ''

      # Identify chunks touched by the indices
      chunk_start_idx <- floor((start - 1L) / chunk_shape)
      chunk_end_idx   <- floor((stop - 1L) / chunk_shape)
      grid_idx <- as.matrix(expand.grid(
        lapply(seq_len(nd), function(d) seq(chunk_start_idx[d], chunk_end_idx[d]))))

      # Loop over the chunks
      for (i in seq_len(nrow(grid_idx))) {
        cidx <- grid_idx[i, ]
        chunk_key <- paste0(private$.array_prefix, chunk_pre, paste(cidx, collapse = sep))

        # Compute slice within the chunk
        chunk_origin  <- cidx * chunk_shape + 1L
        overlap_start <- pmax(start, chunk_origin)
        overlap_end   <- pmin(stop, chunk_origin + chunk_shape - 1L)
        overlap_count <- overlap_end - overlap_start + 1L

        # Get or create chunk IO object
        if (!exists(chunk_key, private$.chunk_map, inherits = FALSE)) {
          private$.chunk_map[[chunk_key]] <- chunk_grid_regular_IO$new(
            key = chunk_key,
            chunk_shape = chunk_shape,
            dtype = private$.data_type,
            store = private$.store,
            codecs = private$.codecs
          )
        }

        # Read overlapping chunk data and copy into data
        chunk_data <- private$.chunk_map[[chunk_key]]$read(overlap_start - chunk_origin, overlap_count)
        data_start <- overlap_start - start
        idx <- lapply(seq_len(nd), function(d)
          seq(data_start[d] + 1L, data_start[d] + overlap_count[d]))
        data <- do.call(`[<-`, c(list(data), idx, list(value = chunk_data)))
      }

      # Set the dims in the right order as per the transpose codec
      dims <- length(private$.chunk_shape)
      trans <- private$.codecs$transpose$configuration$order %||% 0L:(dims - 1L)
      dim(data) <- dim(data)[dims - trans]

      data
    },

    #' @description Write data to the array.
    #' @param data An R object with the same dimensionality as the Zarr array.
    #' @param start,stop Integer vectors of the same length as the
    #'   dimensionality of the Zarr array, indicating the starting and ending
    #'   (inclusive) indices of the data along each axis.
    #' @return Self, invisibly.
    write = function(data, start, stop) {
      chunk_shape  <- private$.chunk_shape
      nd <- length(chunk_shape)
      sep <- private$.chunk_sep

      # Identify chunks touched by this hyperslab of data
      chunk_start_idx <- floor((start - 1L) / chunk_shape)
      chunk_end_idx   <- floor((stop - 1L) / chunk_shape)

      grid_idx <- as.matrix(expand.grid(
        lapply(seq_len(nd), function(d) seq(chunk_start_idx[d], chunk_end_idx[d]))))

      # Loop over the chunks
      for (i in seq_len(nrow(grid_idx))) {
        cidx <- grid_idx[i, ]
        chunk_key <- paste0(private$.array_prefix, paste('c', paste(cidx, collapse = sep), sep = sep))

        # Compute slice within the chunk
        chunk_origin  <- cidx * chunk_shape + 1L
        overlap_start <- pmax(start, chunk_origin)
        overlap_end   <- pmin(stop, chunk_origin + chunk_shape - 1L)
        overlap_count <- overlap_end - overlap_start + 1L

        # Extract corresponding data slice
        data_start <- overlap_start - start
        idx <- lapply(seq_len(nd), function(d)
          seq(data_start[d] + 1L, data_start[d] + overlap_count[d]))
        data_slice <- do.call(`[`, c(list(data), idx, list(drop = FALSE)))

        # Get or create chunk IO object
        if (!exists(chunk_key, private$.chunk_map, inherits = FALSE)) {
          private$.chunk_map[[chunk_key]] <- chunk_grid_regular_IO$new(
            key = chunk_key,
            chunk_shape = chunk_shape,
            dtype = private$.data_type,
            store = private$.store,
            codecs = private$.codecs
          )
        }

        # Queue synchronous write
        private$.chunk_map[[chunk_key]]$write(
          data = data_slice,
          offset = overlap_start - chunk_origin,
          flush = TRUE
        )
      }
      invisible(self)
    }
  ),
  active = list(
    #' @field chunk_shape (read-only) The dimensions of each chunk in the chunk
    #' grid of the associated array.
    chunk_shape = function(value) {
      if (missing(value))
        private$.chunk_shape
    },

    #' @field chunk_grid (read-only) The chunk grid of the associated array,
    #'   i.e. the number of chunks in each dimension.
    chunk_grid = function(value) {
      if (missing(value))
        private$.chunk_grid
    },

    #' @field chunk_separator Set or retrieve the separator to be used for
    #' creating store keys for chunks.
    chunk_separator = function(value) {
      if (missing(value))
        private$.chunk_sep
      else
        private$.chunk_sep <- value
    },

    #' @field data_type The data type of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    data_type = function(value) {
      if (missing(value))
        private$.data_type
      else if (inherits(value, 'zarr_data_type'))
        private$.data_type <- value
      else
        stop('Must set a valid data type.', call. = FALSE) # nocov
    },

    #' @field codecs The list of codecs used by the chunking scheme. These are
    #' set by the array when starting to use chunking for file I/O. Upon
    #' reading, the list of registered codecs.
    codecs = function(value) {
      if (missing(value))
        private$.codecs
      else if (is.list(value) && all(sapply(value, inherits, 'zarr_codec')))
        private$.codecs <- value
      else
        stop('Invalid list of codecs for chunk management.', call. = FALSE) # nocov
    },

    #' @field store The store of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    store = function(value) {
      if (missing(value))
        private$.store
      else if (inherits(value, 'zarr_store'))
        private$.store <- value
      else
        stop('Bad assignment of store.', call. = FALSE) # nocov
    },

    #' @field array_prefix The prefix of the array using the chunking scheme.
    #'   This is set by the array when starting to use chunking for file I/O.
    array_prefix = function(value) {
      if (missing(value))
        private$.array_prefix
      else
        private$.array_prefix <- value
    }
  )
)

#' Reader / Writer class for regular chunked arrays
#'
#' @description Process the data of an individual chunk on a regular grid. This
#'   class will read the chunk from the store and decode it (as necessary), then
#'   merge the new data with it, encode the updated chunk and write back to the
#'   store.
#' @docType class
#' @keywords internal
chunk_grid_regular_IO <- R6::R6Class('chunk_grid_regular_IO',
  cloneable = FALSE,
  private = list(
    # Internal buffer of chunk data, keep track of any change made.
    .buffer = NULL,
    .buffer_stale = FALSE,

    .store = NULL,
    .data_type = NULL,
    .codecs = list(),
    .chunk_key = '',
    .chunk_shape = NULL,

    # Load the chunk and decode it. Result is placed in private$.buffer.
    load_chunk = function() {
      if (is.null(private$.buffer)) {
        buf <- private$.store$get(private$.chunk_key)
        private$.buffer <- if (is.null(buf)) {
          # No chunk in the store, initialize buffer with fill_data
          array(rep(private$.data_type$fill_value, prod(private$.chunk_shape)), private$.chunk_shape)
        } else {
          # Decode the chunk
          for (i in length(private$.codecs):1L)
            buf <- private$.codecs[[i]]$decode(buf)
          buf
        }
      }
    },

    # Make sure that any edits are written to the store before disappearing.
    finalize = function() {
      self$flush()
    }
  ),
  public = list(
    #' @description Create a new instance of this class.
    #' @param key The key of the chunk in the store.
    #' @param chunk_shape Integer vector with the shape of the chunk.
    #' @param dtype The [zarr_data_type] of the array.
    #' @param store The [zarr_store] instance that is the store of this array.
    #' @param codecs List of [zarr_codec] instances to use. The list will be
    #' copied such that this chunk reader/writer can be run asynchronously.
    initialize = function(key, chunk_shape, dtype, store, codecs) {
      private$.chunk_key <- key
      private$.chunk_shape <- chunk_shape
      private$.data_type <- dtype
      private$.store <- store
      private$.codecs <- lapply(codecs, function(c) c$copy())
    },

    #' @description Read some data from the chunk.
    #' @param offset,length The integer offsets and length that determine where
    #'   from the chunk to read the data.
    #' @return The requested data, as an R object with dimensions set when it is
    #'   a matrix or array.
    read = function(offset, length) {
      private$load_chunk()
      nd <- length(private$.chunk_shape)
      chunk_idx <- vector("list", nd)
      for (d in seq_len(nd))
        chunk_idx[[d]] <- seq.int(offset[d] + 1L, offset[d] + length[d])
      do.call(`[`, c(list(private$.buffer), chunk_idx, list(drop = FALSE)))
    },

    #' @description Write some data to the chunk.
    #' @param data The data to write to the chunk.
    #' @param offset The integer offsets that determine where in the chunk to
    #'   write the data. Ignored if argument `data` has a full chunk of data.
    #' @param flush If `TRUE`, the chunk will be written to file iimediately
    #'   after writing the new data to it. If `FALSE`, data will be written to
    #'   the chunk but not persisted to the store - this is more efficient when
    #'   writing multiple slabs of data to a chunk.
    #' @return Self, invisibly.
    write = function(data, offset, flush = FALSE) {
      nd <- length(private$.chunk_shape)
      data_size <- dim(data) %||% length(data)

      # If data covers the full chunk, simply link it to the buffer
      if (all(data_size == private$.chunk_shape) && length(data_size) == nd) {
        private$.buffer <- data
        private$.buffer_stale <- TRUE
      } else {
        private$load_chunk()

        # Write data to the chunk buffer
        chunk_idx <- vector("list", nd)
        for (d in seq_len(nd))
          chunk_idx[[d]] <- seq.int(offset[d] + 1L, offset[d] + data_size[d])

        private$.buffer <- do.call(`[<-`, c(list(private$.buffer), chunk_idx, list(value = data)))
        private$.buffer_stale <- TRUE
      }

      if (flush) self$flush()
      invisible(self)
    },

    #' @description If the chunk has changed applied to it, persist the chunk to
    #'   the store.
    #' @return Self, invisibly.
    flush = function() {
      if (private$.buffer_stale) {
        if (all(is.na(private$.buffer))) {
          # If the entire buffer is NA, don't write it, delete existing chunk
          private$.store$erase(private$.chunk_key)
        } else {
          # Encode the buffer
          buf <- private$.buffer
          for (i in seq_len(length(private$.codecs)))
            buf <- private$.codecs[[i]]$encode(buf)

          # Write to the store
          private$.store$set(private$.chunk_key, buf)
        }
        private$.buffer_stale <- FALSE
      }
      invisible(self)
    }
  )
)

# --- S3 functions ---
#' Compact display of a regular chunk grid
#' @param object A `chunk_grid_regular` instance.
#' @param ... Ignored.
#' @export
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' tas <- africa[["/tas"]]
#' str(tas$chunking)
str.chunk_grid_regular <- function(object, ...) {
  cat('Zarr regular chunk grid: [', paste(object$chunk_shape, collapse = ', '), ']\n', sep = '')
}
