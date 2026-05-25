#' Sharding chunk management
#'
#' @description This class implements the sharded chunk grid for Zarr
#'   arrays. It manages reading from Zarr stores, using the
#'   codecs for data transformation included in the sharding configuration.
#'   Writing is not supported with this codec. Storing a scalar array in a
#'   sharded grid is not possible either and totally useless anyway.
#' @docType class
chunk_grid_sharded <- R6::R6Class('chunk_grid_sharded',
  inherit = chunking,
  cloneable = FALSE,
  private = list(
    .inner_shape  = NULL,  # inner chunk shape
    .inner_grid   = NULL,  # prod(.chunk_shape / .inner_shape) inner chunks
    .index_loc    = NULL,  # "end" or "start"
    .inner_codecs = NULL,  # instantiated inner codec pipeline
    .index        = NULL,  # cached index matrix [n_inner x 2] (offset, length)
    .index_codecs = NULL   # instantiated index codec pipeline
  ),
  public = list(
    #' @description Initialize a new sharded chunking scheme for an array.
    #' @param array_shape Integer vector of the array dimensions.
    #' @param chunk_shape Integer vector of the dimensions of each outer chunk,
    #'   i.e. the size of a shard.
    #' @param inner_shape Integer vector of the dimensions of each inner chunk,
    #'   i.e. the size of a single chunk inside a shard.
    #' @param index_loc Location of the shard index in the shard file, either
    #'   "start" or "end".
    #' @param inner_codecs,index_codecs List of `zarr_codec` instances to decode
    #'   the inner chunks and the index, respectively.
    #' @return An instance of `chunk_grid_sharded`.
    initialize = function(array_shape, chunk_shape, inner_shape, index_loc,
                          inner_codecs, index_codecs) {
      super$initialize('sharding_indexed', array_shape, chunk_shape)
      if (private$.scalar)
        stop('Cannot use sharding on a scalar array', call. = FALSE)

      private$.inner_shape  <- inner_shape
      private$.inner_grid   <- as.integer(chunk_shape / inner_shape)
      private$.index_loc    <- index_loc
      private$.inner_codecs <- inner_codecs
      private$.index_codecs <- index_codecs
    },

    #' @description Print a short description of this sharded chunking scheme to
    #'   the console.
    #' @return Self, invisibly.
    print = function() {
      cat('<Zarr sharded chunk grid> [', paste(private$.chunk_shape, collapse = ', '), ']\n', sep = '')
      invisible(self)
    },

    #' @description Return the metadata fragment that describes this chunking
    #'   scheme.
    #' @return A list with the metadata of this chunking scheme.
    metadata_fragment = function() {
      list(
        chunk_grid = list(
          name = 'regular',
          configuration = list(
            chunk_shape = private$.chunk_shape
          )
        ),
        codecs = list(
          list(
            name = 'sharding_indexed',
            configuration = list(
              chunk_shape    = private$.inner_shape,
              codecs         = lapply(private$.inner_codecs, function(cdc) cdc$metadata_fragment()),
              index_codecs   = lapply(private$.index_codecs, function(cdc) cdc$metadata_fragment()),
              index_location = private$.index_loc
            )
          )
        )
      )
    },

    #' @description Read data from the Zarr array into an R object.
    #' @param start,stop Integer vectors of the same length as the
    #'   dimensionality of the Zarr array, indicating the starting and ending
    #'   (inclusive) indices of the data along each axis.
    #' @return A vector, matrix or array of data.
    read = function(start, stop) {
      shard_shape <- private$.chunk_shape
      inner_shape <- private$.inner_shape
      nd <- length(shard_shape)

      # Identify shards touched by the selection (outer grid)
      shard_start_idx <- floor((start - 1L) / shard_shape)
      shard_end_idx   <- floor((stop  - 1L) / shard_shape)
      shard_grid <- as.matrix(expand.grid(
        lapply(seq_len(nd), function(d) seq(shard_start_idx[d], shard_end_idx[d]))))

      # Output array
      nd_out <- stop - start + 1L
      data <- if (nd == 1L) vector(private$.data_type$Rtype, nd_out)
              else array(private$.data_type$fill_value, nd_out)

      # Loop over shards
      for (i in seq_len(nrow(shard_grid))) {
        cidx      <- shard_grid[i, ]
        shard_key <- paste0(private$.array_prefix, private$.cke$pre,
                            paste(cidx, collapse = private$.cke$sep))

        shard_origin  <- cidx * shard_shape + 1L
        overlap_start <- pmax(start, shard_origin)
        overlap_end   <- pmin(stop,  shard_origin + shard_shape - 1L)

        # Get or create shard IO object
        if (!exists(shard_key, private$.chunk_map, inherits = FALSE)) {
          private$.chunk_map[[shard_key]] <- chunk_grid_sharded_IO$new(
            key          = shard_key,
            shard_shape  = shard_shape,
            inner_shape  = inner_shape,
            inner_codecs = private$.inner_codecs,
            index_codecs = private$.index_codecs,
            index_loc    = private$.index_loc,
            dtype        = private$.data_type,
            store        = private$.store
          )
        }

        # Read from shard and place into output array
        chunk_data <- private$.chunk_map[[shard_key]]$read(
          overlap_start - shard_origin, overlap_end - overlap_start + 1L)
        data_start <- overlap_start - start
        idx <- lapply(seq_len(nd), function(d)
          seq(data_start[d] + 1L, data_start[d] + (overlap_end[d] - overlap_start[d]) + 1L))
        data <- do.call(`[<-`, c(list(data), idx, list(value = chunk_data)))
      }

      data
    }
  ),
  active = list(
    #' @field inner_shape (read-only) The dimensions of each chunk in the shard.
    inner_shape = function(value) {
      if (missing(value))
        private$.inner_shape
    },

    #' @field codecs (read-only) The list of codecs used by the sharding scheme.
    codecs = function(value) {
      if (missing(value))
        private$.inner_codecs
    },

    #' @field index_codecs (read-only) The list of codecs used by the sharding
    #'   scheme for the indexing of the internal chunks.
    index_codecs = function(value) {
      if (missing(value))
        private$.index_codecs
    }
  )
)

#' Reader class for sharded arrays
#'
#' @description Process the data of an individual chunk in a shard file on a
#'   sharded grid. This class will read the chunk from the shard file in the
#'   store using its byte range and decode it.
#' @docType class
#' @keywords internal
chunk_grid_sharded_IO <- R6::R6Class('chunk_grid_sharded_IO',
  cloneable = FALSE,
  private = list(
    .store        = NULL,
    .key          = NULL,   # store key of this shard file
    .shard_shape  = NULL,
    .inner_shape  = NULL,
    .inner_grid   = NULL,   # number of inner chunks per dimension
    .inner_codecs = NULL,
    .index_codecs = NULL,
    .index_loc    = NULL,
    .data_type    = NULL,
    .index        = NULL,   # cached after first load: matrix [n_inner x 2] (offset, length)
    .chunk_map    = NULL,   # inner key -> decoded array (lazy, cached)

    # Load and cache the shard index. If the return value is FALSE, there is no shard file.
    load_index = function() {
      if (!is.null(private$.index)) return(TRUE)

      if (!requireNamespace('bit64', quietly = TRUE))
        stop('Package \'bit64\' must be installed to read sharded arrays.', call. = FALSE)

      n_inner    <- prod(private$.inner_grid)
      n_cdcs     <- length(private$.index_codecs)

      # Determine raw index byte size from the index codec pipeline.
      # The bytes codec always produces n_inner * 2 * 8 bytes (uint64 pairs).
      # If a crc32c codec is present it appends 4 bytes.
      has_crc <- any(sapply(private$.index_codecs, function(c) c$name == 'crc32c'))
      index_bytes <- n_inner * 16L + if (has_crc) 4L else 0L

      raw <- if (private$.index_loc == 'end')
        private$.store$get(private$.key, byte_range = -index_bytes)
      else
        private$.store$get(private$.key, byte_range = c(0L, index_bytes))

      if (is.null(raw)) return(FALSE)

      # Run index codec pipeline in reverse (decode)
      buf <- raw
      for (i in n_cdcs:1L)
        buf <- private$.index_codecs[[i]]$decode(buf)

      # Interpret as integer64
      class(buf) <- 'integer64'
      dim(buf) <- c(2L, n_inner)
      private$.index <- buf
      return(TRUE)
    },

    # Translate an inner chunk grid index vector to a linear row in the index
    # table. The Zarr spec uses C order (last dimension varies fastest).
    inner_linear = function(cidx) {
      nd <- length(private$.inner_grid)
      # C-order strides: last dimension has stride 1, first has largest stride
      strides <- c(rev(cumprod(rev(private$.inner_grid)))[-1L], 1L)
      sum(cidx * strides) + 1L
    },

    # Read and decode a single inner chunk, returning a full inner-shaped array.
    # Returns NULL if the inner chunk is absent (sentinel).
    load_inner = function(cidx) {
      linear <- private$inner_linear(cidx)
      entry  <- private$.index[ , linear]

      # Sentinel: both offset and length are 0xFFFFFFFFFFFFFFFF (-1L in integer64)
      if (entry[1L] == bit64::as.integer64(-1L)) return(NULL)

      # Ranged read of the inner chunk bytes from the shard file
      ic_offset <- as.numeric(entry[1L])
      ic_length <- as.numeric(entry[2L])
      raw <- private$.store$get(private$.key, byte_range = c(ic_offset, ic_offset + ic_length))

      # Decode inner chunk through inner codec pipeline (reverse order)
      buf <- raw
      n_cdcs <- length(private$.inner_codecs)
      for (i in n_cdcs:1L)
        buf <- private$.inner_codecs[[i]]$decode(buf)

      # If no transpose codec, data is in C order: flip dims and permute to R order
      if (private$.inner_codecs[[1L]]$name != 'transpose') {
        dim(buf) <- rev(private$.inner_shape)
        buf <- aperm(buf, rev(seq_along(private$.inner_shape)))
      }
      buf
    }
  ),
  public = list(
    #' @description Create a new IO handler for a single shard.
    #' @param key Store key for this shard file.
    #' @param shard_shape Integer vector, the shape of this shard.
    #' @param inner_shape Integer vector, the shape of each inner chunk.
    #' @param inner_codecs List of [zarr_codec] instances for inner chunks.
    #' @param index_codecs List of [zarr_codec] instances for the index.
    #' @param index_loc Character, `"end"` or `"start"`.
    #' @param dtype A [zarr_data_type] instance.
    #' @param store A [zarr_store] instance.
    initialize = function(key, shard_shape, inner_shape, inner_codecs,
           index_codecs, index_loc, dtype, store) {
      private$.key          <- key
      private$.shard_shape  <- shard_shape
      private$.inner_shape  <- inner_shape
      private$.inner_grid   <- as.integer(shard_shape / inner_shape)
      private$.inner_codecs <- inner_codecs
      private$.index_codecs <- index_codecs
      private$.index_loc    <- index_loc
      private$.data_type    <- dtype
      private$.store        <- store
      private$.chunk_map    <- new.env(parent = emptyenv())
    },

    #' @description Read a region from this shard.
    #' @param offset Integer vector of 0-based offsets into the shard.
    #' @param length Integer vector of lengths along each dimension.
    #' @return An array of decoded data.
    read = function(offset, length) {
      # Output array, initialised with fill value
      nd   <- length(private$.inner_shape)
      data <- if (nd == 1L) rep(private$.data_type$fill_value, length)
              else array(private$.data_type$fill_value, length)

      if (private$load_index()) {
        # Identify inner chunks touched by offset/length
        stop <- offset + length - 1L
        inner_start_idx <- floor(offset / private$.inner_shape)
        inner_end_idx   <- floor(stop   / private$.inner_shape)
        inner_grid <- as.matrix(expand.grid(
        lapply(seq_len(nd), function(d) seq(inner_start_idx[d], inner_end_idx[d]))))


        for (i in seq_len(nrow(inner_grid))) {
          cidx <- inner_grid[i, ]

          ic_data <- private$load_inner(cidx)
          if (is.null(ic_data)) next   # absent inner chunk, fill value already in output

          # Overlap of this inner chunk with the requested region (shard-local coords)
          inner_origin  <- cidx * private$.inner_shape
          overlap_start <- pmax(offset, inner_origin)
          overlap_end   <- pmin(stop,   inner_origin + private$.inner_shape - 1L)
          overlap_count <- overlap_end - overlap_start + 1L

          # Slice from the decoded inner chunk
          ic_idx <- lapply(seq_len(nd), function(d)
            seq(overlap_start[d] - inner_origin[d] + 1L,
                overlap_start[d] - inner_origin[d] + overlap_count[d]))
          ic_slice <- do.call(`[`, c(list(ic_data), ic_idx, list(drop = FALSE)))

          # Place into output array
          out_idx <- lapply(seq_len(nd), function(d)
            seq(overlap_start[d] - offset[d] + 1L,
                overlap_start[d] - offset[d] + overlap_count[d]))
          data <- do.call(`[<-`, c(list(data), out_idx, list(value = ic_slice)))
        }
      }
      data
    }
  )
)

# --- S3 functions ---

#' Compact display of a sharding chunk grid
#' @param object A `chunk_grid_sharded` instance.
#' @param ... Ignored.
#' @export
str.chunk_grid_sharded <- function(object, ...) {
  cat('Zarr sharded chunk grid: [', paste(object$shard_shape, collapse = ', '), ']\n', sep = '')
}
