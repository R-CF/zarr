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
              codecs         = unname(lapply(private$.inner_codecs, function(cdc) cdc$metadata_fragment())),
              index_codecs   = unname(lapply(private$.index_codecs, function(cdc) cdc$metadata_fragment())),
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
      nd          <- length(shard_shape)

      # Identify shards touched by the selection (outer grid)
      shard_start_idx <- floor((start - 1L) / shard_shape)
      shard_end_idx   <- floor((stop  - 1L) / shard_shape)
      shard_grid <- as.matrix(expand.grid(
        lapply(seq_len(nd), function(d) seq(shard_start_idx[d], shard_end_idx[d]))))

      # Output array
      nd_out <- stop - start + 1L
      data <- if (nd == 1L) vector(private$.data_type$Rtype, nd_out)
      else array(private$.data_type$fill_value, nd_out)

      # Capture all shard-invariant values needed by fetch_one()
      # These are passed explicitly to avoid closure serialisation issues
      # when running under a parallel future plan
      inner_codecs <- private$.inner_codecs
      index_codecs <- private$.index_codecs
      index_loc    <- private$.index_loc
      data_type    <- private$.data_type
      store        <- private$.store

      # Compute shard geometry for all shards upfront
      n_shards <- nrow(shard_grid)
      shard_info <- lapply(seq_len(n_shards), function(i) {
        cidx          <- shard_grid[i, ]
        shard_key     <- paste0(private$.array_prefix, private$.cke$pre,
                                paste(cidx, collapse = private$.cke$sep))
        shard_origin  <- cidx * shard_shape + 1L
        overlap_start <- pmax(start, shard_origin)
        overlap_end   <- pmin(stop,  shard_origin + shard_shape - 1L)
        list(
          key           = shard_key,
          overlap_start = overlap_start,
          overlap_end   = overlap_end,
          offset        = overlap_start - shard_origin,
          length        = overlap_end - overlap_start + 1L
        )
      })

      # Fetch an individual shard
      fetch_shard <- function(info) {
        io <- chunk_grid_sharded_IO$new(
          key          = info$key,
          shard_shape  = shard_shape,
          inner_shape  = inner_shape,
          inner_codecs = inner_codecs,
          index_codecs = index_codecs,
          index_loc    = index_loc,
          dtype        = data_type,
          store        = store
        )
        list(
          chunk_data    = io$read(info$offset, info$length),
          overlap_start = info$overlap_start,
          overlap_end   = info$overlap_end
        )
      }

      # Parallel fetch + decode per shard if a parallel future plan is active,
      # otherwise fall back to sequential lapply()
      use_parallel <- n_shards > Zarr.options$parallel_threshold &&
                      requireNamespace('future.apply', quietly = TRUE) &&
                      requireNamespace('future', quietly = TRUE) &&
                      !inherits(future::plan(), 'sequential')

      shard_results <- if (use_parallel)
        future.apply::future_lapply(shard_info, fetch_shard,
                                    future.seed     = NULL,
                                    future.packages = c('zarr', 'bit64'))
      else
        lapply(shard_info, fetch_shard)

      # Sequential assembly into output array
      for (res in shard_results) {
        data_start <- res$overlap_start - start
        idx <- lapply(seq_len(nd), function(d)
          seq(data_start[d] + 1L,
              data_start[d] + (res$overlap_end[d] - res$overlap_start[d]) + 1L))
        data <- do.call(`[<-`, c(list(data), idx, list(value = res$chunk_data)))
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
#' @description Process the data of an individual shard file. This class reads
#'   the shard index and decodes inner chunks on demand, caching decoded inner
#'   chunks to avoid redundant I/O and decoding on overlapping selections.
#'   Inner chunks needed for a given read are fetched in a single coalesced
#'   byte-range request covering all required inner chunks, minimising the
#'   number of store requests — particularly important for HTTP stores.
#' @docType class
#' @keywords internal
chunk_grid_sharded_IO <- R6::R6Class('chunk_grid_sharded_IO',
  cloneable = FALSE,
  private = list(
    .store         = NULL,
    .key           = NULL,   # store key of this shard file
    .shard_shape   = NULL,
    .inner_shape   = NULL,
    .inner_grid    = NULL,   # number of inner chunks per dimension
    .inner_codecs  = NULL,
    .index_codecs  = NULL,
    .index_loc     = NULL,
    .data_type     = NULL,
    .index         = NULL,   # cached after first load: [2 x n_inner] integer64 matrix
    .decoded_cache = NULL,   # environment: linear index (char) -> decoded R array

    # Load and cache the shard index.
    # Returns TRUE if the index was loaded successfully, FALSE if the shard
    # file does not exist in the store.
    load_index = function() {
      if (!is.null(private$.index)) return(TRUE)

      if (!requireNamespace('bit64', quietly = TRUE))
      stop('Package \'bit64\' must be installed to read sharded arrays.', call. = FALSE)

      n_inner <- prod(private$.inner_grid)
      n_cdcs  <- length(private$.index_codecs)

      # Determine raw index byte size from the index codec pipeline.
      # The bytes codec always produces n_inner * 2 * 8 bytes (uint64 pairs).
      # If a crc32c codec is present it appends 4 bytes.
      has_crc     <- any(sapply(private$.index_codecs, function(c) c$name == 'crc32c'))
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

      # Reinterpret decoded bytes as integer64 (bitwise, not numeric conversion)
      # and reshape to [2 x n_inner]: row 1 = offsets, row 2 = lengths
      class(buf) <- 'integer64'
      dim(buf)   <- c(2L, n_inner)
      private$.index <- buf
      TRUE
    },

    # Translate an inner chunk grid index vector to a 1-based linear column
    # index into the shard index matrix. The Zarr spec uses C order (last
    # dimension varies fastest).
    inner_linear = function(cidx) {
      nd      <- length(private$.inner_grid)
      strides <- c(rev(cumprod(rev(private$.inner_grid)))[-1L], 1L)
      sum(cidx * strides) + 1L
    },

    # Decode a single inner chunk from a pre-fetched buffer and store it in
    # the decoded cache. `shard_buf` is the raw bytes of the coalesced read;
    # `span_start` is the byte offset within the shard file at which
    # `shard_buf` begins.
    decode_inner = function(cidx, shard_buf, span_start) {
      linear <- private$inner_linear(cidx)
      key    <- as.character(linear)

      # Already decoded and cached
      if (exists(key, private$.decoded_cache, inherits = FALSE)) return()

      entry <- private$.index[, linear]

      # Sentinel: inner chunk absent
      if (entry[1L] == bit64::as.integer64(-1L)) {
        private$.decoded_cache[[key]] <- NULL
        return()
      }

      # Extract inner chunk bytes from the coalesced buffer (1-based indexing)
      ic_start <- as.numeric(entry[1L]) - span_start + 1L
      ic_len   <- as.numeric(entry[2L])
      ic_raw   <- shard_buf[ic_start:(ic_start + ic_len - 1L)]

      # Decode through inner codec pipeline (reverse order)
      buf    <- ic_raw
      n_cdcs <- length(private$.inner_codecs)
      for (i in n_cdcs:1L)
        buf <- private$.inner_codecs[[i]]$decode(buf)

      # If no transpose codec, data is in C order: flip dims and permute to R order
      if (private$.inner_codecs[[1L]]$name != 'transpose') {
        dim(buf) <- rev(private$.inner_shape)
        buf      <- aperm(buf, rev(seq_along(private$.inner_shape)))
      }

      private$.decoded_cache[[key]] <- buf
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
      private$.key           <- key
      private$.shard_shape   <- shard_shape
      private$.inner_shape   <- inner_shape
      private$.inner_grid    <- as.integer(shard_shape / inner_shape)
      private$.inner_codecs  <- inner_codecs
      private$.index_codecs  <- index_codecs
      private$.index_loc     <- index_loc
      private$.data_type     <- dtype
      private$.store         <- store
      private$.decoded_cache <- new.env(parent = emptyenv())
    },

    #' @description Read a region from this shard.
    #'
    #' Inner chunks needed for this read are fetched in a single coalesced
    #' byte-range request. Previously decoded inner chunks are served from
    #' cache without any store access.
    #'
    #' @param offset Integer vector of 0-based offsets into the shard.
    #' @param length Integer vector of lengths along each dimension.
    #' @return An array of decoded data.
    read = function(offset, length) {
      nd   <- length(private$.inner_shape)
      data <- if (nd == 1L) rep(private$.data_type$fill_value, length)
              else array(private$.data_type$fill_value, length)

      if (!private$load_index()) return(data)

      stop <- offset + length - 1L

      # Identify inner chunks touched by offset/length
      inner_start_idx <- floor(offset / private$.inner_shape)
      inner_end_idx   <- floor(stop   / private$.inner_shape)
      inner_grid <- as.matrix(expand.grid(
                      lapply(seq_len(nd), function(d) seq(inner_start_idx[d], inner_end_idx[d]))))

      # Pass 1: classify inner chunks as cached, absent (sentinel), or to fetch
      all_entries <- lapply(seq_len(nrow(inner_grid)), function(i) {
        cidx   <- inner_grid[i, ]
        linear <- private$inner_linear(cidx)
        key    <- as.character(linear)
        entry  <- private$.index[, linear]

        # Sentinel: inner chunk absent from shard
        if (entry[1L] == bit64::as.integer64(-1L)) return(NULL)

        list(cidx   = cidx,
             linear = linear,
             key    = key,
             offset = as.numeric(entry[1L]),
             length = as.numeric(entry[2L]),
             cached = exists(key, private$.decoded_cache, inherits = FALSE))
      })
      # NULL entries are absent inner chunks; remove them
      all_entries <- Filter(Negate(is.null), all_entries)

      if (!length(all_entries)) return(data)

      # Pass 2: coalesced fetch for uncached inner chunks (single store request)
      uncached <- Filter(function(e) !e$cached, all_entries)
      if (length(uncached)) {
        span_start <- min(sapply(uncached, `[[`, 'offset'))
        span_end   <- max(sapply(uncached, function(e) e$offset + e$length))
        shard_buf  <- private$.store$get(private$.key, byte_range = c(span_start, span_end))
        for (e in uncached)
          private$decode_inner(e$cidx, shard_buf, span_start)
      }

      # Pass 3: assemble output array from decoded cache
      # Collect all non-absent entries
      present <- Filter(function(e) {
        !is.null(private$.decoded_cache[[e$key]])
      }, all_entries)

      if (length(present)) {
        chunks      <- lapply(present, function(e) private$.decoded_cache[[e$key]])
        out_offsets <- vector('list', length(present))
        ic_offsets  <- vector('list', length(present))
        copy_lens   <- matrix(0L, nrow = nd, ncol = length(present))

        for (j in seq_along(present)) {
          e             <- present[[j]]
          inner_origin  <- e$cidx * private$.inner_shape
          overlap_start <- pmax(offset, inner_origin)
          overlap_end   <- pmin(stop,   inner_origin + private$.inner_shape - 1L)
          overlap_count <- overlap_end - overlap_start + 1L

          out_offsets[[j]] <- overlap_start - offset          # 0-based in output
          ic_offsets[[j]]  <- overlap_start - inner_origin    # 0-based in inner chunk
          copy_lens[, j]   <- overlap_count
        }

        out_dims <- dim(data) %||% length(data)
        ic_dims  <- private$.inner_shape  # always a vector, never NULL

        fill_array_impl(data, chunks, out_offsets, ic_offsets,
                        copy_lens, as.integer(out_dims), as.integer(ic_dims))      }
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
