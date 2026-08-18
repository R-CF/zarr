#' Zarr Store for AWS S3 (and S3-compatible) access
#'
#' @description This class implements a Zarr S3 store, read/write capable for
#'   authenticated users. It uses the `paws.storage` package for all S3
#'   operations, including credential resolution, so this class never handles
#'   secret keys directly unless the caller explicitly passes them through.
#'
#'   Like [zarr_httpstore], this class will look for consolidated metadata
#'   (`.zmetadata`) or a `zarr.json` / `.zarray` / `.zgroup` document at the
#'   configured prefix to identify the store version and root node. Unlike the
#'   HTTP store, this class does not *need* consolidated metadata to enumerate
#'   nodes: S3's `ListObjectsV2` API is used directly for `list_dir()` and
#'   `list_prefix()`, so the store reflects the live state of the bucket.
#'
#'   Credentials are resolved by `paws.storage` using its standard provider
#'   chain (environment variables, shared credentials file / profile, IAM
#'   role or instance/task metadata, SSO). Pass `profile` to select a named
#'   profile, or explicit `access_key`/`secret_key`/`session_token` for
#'   credentials threaded through from elsewhere. If none of those are given,
#'   the store defaults to anonymous (unsigned) requests, since
#'   `paws.storage` does not fall back to anonymous access on its own and
#'   the common case for a freshly-opened store is a public bucket; pass
#'   `anonymous = FALSE` explicitly to force normal credential resolution
#'   with none of the above supplied (e.g. to pick up IAM role / instance
#'   metadata credentials with no explicit profile or key).
#'
#'   NOTE: this class performs no sanity checks on any of the arguments
#'   passed to the methods, for performance reasons, consistent with
#'   [zarr_httpstore]. It should be accessed through group and array objects.
#' @docType class
#' @export
zarr_s3store <- R6::R6Class('zarr_s3store',
  inherit = zarr_store,
  cloneable = FALSE,
  private = list(
    .bucket     = NULL,        # S3 bucket name
    .key_prefix = '',          # Prefix within the bucket, without leading '/', with trailing '/' if non-empty
    .client     = NULL,        # paws.storage S3 client
    .metadata   = list(),      # The metadata of the object at the root of the store
    .nodes      = character(0),# Cached node paths from consolidated metadata, if present
    .read_only  = FALSE,

    # Build the full S3 key from a store-relative key.
    full_key = function(key) {
      paste0(private$.key_prefix, key)
    },

    # Request an object (or byte range of one) from the bucket. Returns a raw
    # vector, or NULL if the key does not exist. Errors other than "not
    # found" are raised.
    #
    # VERIFY: paws.storage signals a missing key as an R condition rather than
    # a return value. In current paws this is typically catchable as a
    # condition whose message contains "NoSuchKey" (AWS) or "NotFound", and
    # which carries an HTTP status of 404 in `attr(e, "http_status")` /
    # `e$error_response` depending on paws version. Confirm the exact shape
    # against the paws version you pin, and against any S3-compatible backend
    # you target (MinIO's error body differs from AWS's in some versions).
    request = function(key, byte_range = NULL) {
      args <- list(Bucket = private$.bucket, Key = private$full_key(key))

      if (!is.null(byte_range)) {
        if (length(byte_range) == 1L) {
          if (byte_range >= 0L)
            args$Range <- paste0("bytes=", byte_range, "-")
          else
            args$Range <- paste0("bytes=-", abs(byte_range))
        } else {
          # Convert exclusive end to inclusive, matching zarr_httpstore
          args$Range <- paste0("bytes=", byte_range[1L], "-", byte_range[2L] - 1L)
        }
      }

      res <- tryCatch(
        do.call(private$.client$get_object, args),
        error = function(e) {
          if (private$is_not_found(e)) NULL
          else stop(paste("S3 error on key", key, ":", conditionMessage(e)), call. = FALSE)
        }
      )

      if (is.null(res)) NULL
      else {
        body <- res$Body
        # paws returns the object body as a raw vector already; guard against
        # future versions returning a connection instead.
        if (inherits(body, "connection")) {
          on.exit(close(body), add = TRUE)
          readBin(body, 'raw', n = res$ContentLength %||% .Machine$integer.max)
        } else body
      }
    },

    # Best-effort classification of a paws error as "object not found".
    # VERIFY against your installed paws.storage version.
    is_not_found = function(e) {
      msg <- conditionMessage(e)
      grepl("NoSuchKey|NotFound|404|NoSuchBucket", msg, ignore.case = TRUE)
    },

    # Best-effort classification of a paws error as "precondition failed"
    # (HTTP 412), the expected outcome when set_if_not_exists()'s
    # IfNoneMatch condition fails because the key already exists.
    # VERIFY against your installed paws.storage version.
    is_precondition_failed = function(e) {
      msg <- conditionMessage(e)
      grepl("PreconditionFailed|412", msg, ignore.case = TRUE)
    },

    # List keys below a prefix using S3's native ListObjectsV2, handling
    # pagination. With delimiter = '/', CommonPrefixes ("directories") are
    # included alongside any objects sitting directly at that level. With
    # delimiter = '' the full recursive listing is returned. Set want_size =
    # TRUE to also collect Content-Length for each object (used by
    # getsize_prefix()); CommonPrefixes carry no size.
    list_objects = function(prefix, delimiter = '', want_size = FALSE) {
      full_prefix <- private$full_key(prefix)
      keys <- character(0)
      sizes <- numeric(0)
      token <- NULL
      repeat {
        args <- list(Bucket = private$.bucket, Prefix = full_prefix)
        if (nzchar(delimiter)) args$Delimiter <- delimiter
        if (!is.null(token)) args$ContinuationToken <- token
        res <- do.call(private$.client$list_objects_v2, args)

        if (nzchar(delimiter))
          keys <- c(keys, vapply(res$CommonPrefixes %||% list(), function(x) x$Prefix, character(1)))

        contents <- res$Contents %||% list()
        keys <- c(keys, vapply(contents, function(x) x$Key, character(1)))
        if (want_size)
          sizes <- c(sizes, vapply(contents, function(x) as.numeric(x$Size %||% 0L), numeric(1)))

        if (isTRUE(res$IsTruncated)) token <- res$NextContinuationToken
        else break
      }
      list(keys = unique(keys), sizes = sizes)
    }
  ),
  public = list(
    #' @description Create an instance of this class.
    #' @param bucket Character string. The S3 bucket name.
    #' @param prefix Character string. The key prefix within the bucket that
    #'   acts as the root of this store (e.g. `"datasets/mycube/"`). Use `""`
    #'   for the bucket root. A trailing `/` is added if missing and the
    #'   prefix is non-empty.
    #' @param region Character string, AWS region, e.g. `"eu-west-1"`. If
    #'   `NULL`, resolved by `paws.storage` from the environment/config.
    #' @param profile Character string, a named profile from the shared AWS
    #'   credentials file. Ignored if `access_key` is supplied.
    #' @param access_key,secret_key,session_token Optional explicit
    #'   credentials, for cases where they must be threaded through from
    #'   elsewhere rather than resolved by `paws.storage` itself. Prefer
    #'   `profile` or the default provider chain over these.
    #' @param endpoint Character string. Optional custom endpoint URL, for
    #'   S3-compatible backends (MinIO, Ceph RGW, EMBASSY Cloud, etc.) rather
    #'   than AWS S3.
    #' @param path_style Logical. Force path-style addressing
    #'   (`endpoint/bucket/key`) instead of virtual-hosted-style
    #'   (`bucket.endpoint/key`). Non-AWS S3-compatible backends generally
    #'   only support path-style, so this defaults to `TRUE` whenever
    #'   `endpoint` is supplied, and `FALSE` (AWS default) otherwise. Set
    #'   explicitly to override.
    #' @param anonymous Logical. If `TRUE`, make unsigned requests, for
    #'   public buckets. If `FALSE`, use `paws.storage`'s normal credential
    #'   resolution (explicit `profile`/`access_key`, then its default
    #'   provider chain). If left `NULL` (the default), this is decided
    #'   automatically: `TRUE` when neither `profile` nor `access_key` was
    #'   given, `FALSE` otherwise. `paws.storage` does not fall back to
    #'   unsigned requests on its own — a call against a public bucket with
    #'   no credentials configured fails outright rather than trying
    #'   anonymously, which is what this default is for.
    #' @param read_only Logical. If `TRUE`, disable all write methods
    #'   (`set()`, `erase()`, etc. become no-ops), regardless of the
    #'   permissions of the underlying credentials. Default `FALSE`.
    #' @return An instance of this class.
    initialize = function(bucket, prefix = '', region = NULL, profile = NULL,
                          access_key = NULL, secret_key = NULL, session_token = NULL,
                          endpoint = NULL, path_style = NULL, anonymous = NULL, read_only = FALSE) {
      if (!requireNamespace('paws.storage', quietly = TRUE))
        stop('Must install package "paws.storage" for this functionality', call. = FALSE) # nocov

      if (is.null(anonymous))
        anonymous <- is.null(profile) && is.null(access_key)
      if (is.null(path_style))
        path_style <- !is.null(endpoint)

      private$.bucket <- bucket
      private$.key_prefix <- if (nzchar(prefix)) sub('/*$', '/', prefix) else ''
      # private$.read_only is set below via super$initialize()

      cfg <- list()
      if (!is.null(region)) cfg$region <- region
      if (!is.null(endpoint)) cfg$endpoint <- endpoint
      if (isTRUE(path_style)) cfg$s3_force_path_style <- TRUE

      if (isTRUE(anonymous)) {
        cfg$credentials <- list(anonymous = TRUE)
      } else if (!is.null(access_key)) {
        cfg$credentials <- list(creds = list(
          access_key_id = access_key,
          secret_access_key = secret_key,
          session_token = session_token
        ))
      } else if (!is.null(profile)) {
        cfg$credentials <- list(profile = profile)
      }
      # else: leave credentials unset, paws.storage uses its default chain

      private$.client <- paws.storage::s3(config = cfg)

      # First attempt: Locate Zarr v.3 array or group
      meta <- private$request('zarr.json')
      if (!is.null(meta)) {
        meta <- .parse_metadata(rawToChar(meta))
        format <- meta$zarr_format
        if (is.null(format) || format != 3L)
          stop('Incompatible "zarr_format" found in the store:', format %||% '(null)', call. = FALSE) # nocov
      } else {
        # Second attempt: Retrieve the consolidated metadata
        meta <- private$request('.zmetadata')
        if (!is.null(meta)) {
          meta <- .parse_metadata(rawToChar(meta))
          if (meta$zarr_consolidated_format != 1L)
            stop('Unsupported version of consolidated metadata.', call. = FALSE)

          format <- meta$metadata$.zgroup$zarr_format
          if (is.null(format) || format != 2L)
            stop('Incompatible "zarr_format" found in the store:', format %||% '(null)', call. = FALSE) # nocov

          private$.nodes <- unique(sub('/\\.z[a-z]+$', '', names(meta$metadata)))
          private$.nodes <- private$.nodes[!startsWith(private$.nodes, '.z')]
        } else {
          # Final attempt: Locate Zarr v.2 group or array
          meta <- private$request('.zarray')
          if (is.null(meta))
            meta <- private$request('.zgroup')
          if (is.null(meta))
            stop('No compatible store found at s3://', bucket, '/', prefix, call. = FALSE)
          meta <- .parse_metadata(rawToChar(meta))
          format <- meta$zarr_format
          if (is.null(format) || format != 2L)
            stop('Incompatible "zarr_format" found in the store:', format %||% '(null)', call. = FALSE) # nocov
        }
      }
      private$.metadata <- meta

      super$initialize(read_only = read_only, version = format)
    },

    #' @description Check if a key exists in the store.
    #' @param key Character string. The key that the store will be searched for.
    #' @return `TRUE` if argument `key` is found, `FALSE` otherwise.
    exists = function(key) {
      if (is.null(private$.metadata$zarr_consolidated_format)) {
        res <- tryCatch(
          private$.client$head_object(Bucket = private$.bucket, Key = private$full_key(key)),
          error = function(e) NULL
        )
        !is.null(res)
      } else
        key %in% private$.nodes || key %in% names(private$.metadata$metadata)
    },

    #' @description Remove all objects below this store's prefix. No-op if
    #'   the store was opened with `read_only = TRUE`.
    #' @return `TRUE` on success, `FALSE` otherwise.
    clear = function() {
      if (private$.read_only) return(FALSE)
      self$erase_prefix('')
    },

    #' @description Remove a single key from the store. No-op if the store
    #'   was opened with `read_only = TRUE`.
    #' @param key Character string. The key to remove.
    #' @return `TRUE` on success, `FALSE` otherwise.
    erase = function(key) {
      if (private$.read_only) return(FALSE)
      tryCatch({
        private$.client$delete_object(Bucket = private$.bucket, Key = private$full_key(key))
        TRUE
      }, error = function(e) FALSE)
    },

    #' @description Remove all keys below a prefix. Batches deletes in groups
    #'   of up to 1000, the S3 `DeleteObjects` limit. No-op if the store was
    #'   opened with `read_only = TRUE`.
    #' @param prefix Character string. The prefix whose keys to remove.
    #' @return `TRUE` on success, `FALSE` otherwise.
    erase_prefix = function(prefix) {
      if (private$.read_only) return(FALSE)
      keys <- private$list_objects(prefix, delimiter = '')$keys
      if (!length(keys)) return(TRUE)

      ok <- TRUE
      chunks <- split(keys, ceiling(seq_along(keys) / 1000))
      for (chunk in chunks) {
        res <- tryCatch({
          private$.client$delete_objects(
            Bucket = private$.bucket,
            Delete = list(Objects = lapply(chunk, function(k) list(Key = k)), Quiet = TRUE)
          )
          TRUE
        }, error = function(e) FALSE)
        ok <- ok && res
      }
      ok
    },

    #' @description Retrieve the immediate child nodes below a prefix
    #'   (single path component only), using S3's native `Delimiter` support.
    #' @param prefix Character string. The prefix whose nodes to list.
    #' @return A character vector of node names immediately below `prefix`.
    list_dir = function(prefix) {
      full_prefix <- private$full_key(prefix)
      keys <- private$list_objects(prefix, delimiter = '/')$keys
      keys <- sub(paste0('^', full_prefix), '', keys)
      keys <- sub('/$', '', keys)
      unique(keys[nzchar(keys)])
    },

    #' @description Retrieve all keys below a prefix (recursive).
    #' @param prefix Character string. The prefix whose nodes to list.
    #' @return A character vector with all paths found below `prefix`,
    #'   prefixed with `/` for consistency with [zarr_httpstore].
    list_prefix = function(prefix) {
      keys <- private$list_objects(prefix, delimiter = '')$keys
      keys <- sub(paste0('^', private$.key_prefix), '', keys)
      paste0('/', keys)
    },

    #' @description Retrieve all keys in the store.
    #' @return A character vector with all keys found in the store.
    list = function() {
      self$list_prefix('')
    },

    #' @description Retrieve all chunk (and shard) keys stored for the array
    #'   at the given prefix. Used internally to support resizing and
    #'   promoting arrays.
    #' @param prefix The prefix of the array whose chunk keys to retrieve.
    #' @return A character vector of full store keys for chunk/shard files,
    #'   excluding the array's own metadata document.
    list_chunks = function(prefix) {
      keys <- private$list_objects(prefix, delimiter = '')$keys
      keys <- sub(paste0('^', private$.key_prefix), '', keys)
      keys[keys != paste0(prefix, 'zarr.json')]
    },

    #' @description Rename a key in the store, moving its value without
    #'   necessarily reading or re-encoding it. Used internally to support
    #'   resizing and promoting arrays. The default implementation is a plain
    #'   copy, for stores without a cheaper native operation.
    #' @param old_key,new_key Character strings, the source and destination
    #'   keys. `old_key` must exist; `new_key` is overwritten if it exists.
    #' @return Self, invisibly.
    rename = function(old_key, new_key) {
      private$.client$copy_object(
        Bucket = private$.bucket, Key = private$full_key(new_key),
        CopySource = paste0(private$.bucket, '/', private$full_key(old_key))
      )
      private$.client$delete_object(Bucket = private$.bucket, Key = private$full_key(old_key))
      invisible(self)
    },

    #' @description Return the size, in bytes, of a value in the store, via
    #'   a `HeadObject` request (S3-native, no need to download the object).
    #' @param key Character string. The key whose length will be returned.
    #' @return The size, in bytes, of the object.
    getsize = function(key) {
      res <- tryCatch(
        private$.client$head_object(Bucket = private$.bucket, Key = private$full_key(key)),
        error = function(e) {
          if (private$is_not_found(e)) NULL
          else stop(paste("S3 error on key", key, ":", conditionMessage(e)), call. = FALSE)
        }
      )
      if (is.null(res)) stop('Key not found: ', key, call. = FALSE)
      res$ContentLength
    },

    #' @description Return the total size, in bytes, of all objects found
    #'   under the group indicated by `prefix`, summed from a single
    #'   (paginated) `ListObjectsV2` scan rather than per-key `HeadObject`
    #'   calls.
    #' @param prefix Character string. The prefix to groups to scan.
    #' @return The total size, in bytes, as a single numeric value.
    getsize_prefix = function(prefix) {
      sum(private$list_objects(prefix, delimiter = '', want_size = TRUE)$sizes)
    },

    #' @description Is the group empty? Uses a single `MaxKeys = 1`
    #'   `ListObjectsV2` request rather than a full listing.
    #' @param prefix Character string. The prefix to the group to scan.
    #' @return `TRUE` if the group indicated by argument `prefix` has no
    #'   sub-groups or arrays, `FALSE` otherwise.
    is_empty = function(prefix) {
      full_prefix <- private$full_key(prefix)
      res <- private$.client$list_objects_v2(Bucket = private$.bucket, Prefix = full_prefix, MaxKeys = 1L)
      length(res$Contents %||% list()) == 0L
    },

    #' @description Store a `(key, value)` pair. No-op if the store was
    #'   opened with `read_only = TRUE`.
    #'
    #'   Single-request upload only (S3's ~5 GB `PutObject` limit); this is
    #'   not expected to matter for typical Zarr chunk sizes. If you start
    #'   writing very large chunks (or use very large shards), this needs a
    #'   multipart-upload path instead — not implemented here.
    #' @param key Character string. The key to write to.
    #' @param value Raw vector. The data to store.
    #' @return Self, invisibly.
    set = function(key, value) {
      if (!private$.read_only)
        private$.client$put_object(Bucket = private$.bucket, Key = private$full_key(key), Body = value)
      invisible(self)
    },

    #' @description Store a `(key, value)` pair only if the key does not
    #'   already exist. No-op if the store was opened with `read_only =
    #'   TRUE`.
    #'
    #'   Uses a conditional `PutObject` with `IfNoneMatch = "*"` for atomic
    #'   create-if-absent semantics — no separate existence check, no race
    #'   window. This is an AWS S3 feature added in August 2024; it requires
    #'   a `paws.storage` version whose S3 client exposes `IfNoneMatch` on
    #'   `put_object()`, and a backend that honors it. Most S3-compatible
    #'   services (older MinIO releases, some others) reject or ignore the
    #'   header — if you're targeting one of those, this will need a
    #'   fallback to a check-then-put instead, which reintroduces the race.
    #' @param key Character string. The key to write to.
    #' @param value Raw vector. The data to store.
    #' @return Self, invisibly.
    set_if_not_exists = function(key, value) {
      if (!private$.read_only) {
        tryCatch(
          private$.client$put_object(
            Bucket = private$.bucket, Key = private$full_key(key), Body = value,
            IfNoneMatch = "*"
          ),
          error = function(e) {
            # Key already exists: that's the expected, non-error outcome of
            # set_if_not_exists() when the condition fails, so swallow it.
            if (!private$is_precondition_failed(e))
              stop(paste("S3 error on key", key, ":", conditionMessage(e)), call. = FALSE)
          }
        )
      }
      invisible(self)
    },

    #' @description Retrieve the value associated with a given key.
    #' @param key Character string. The key for which to get data.
    #' @param prototype Ignored. The only buffer type that is supported maps
    #'   directly to an R raw vector.
    #' @param byte_range As in [zarr_httpstore]: `NULL` for the whole object,
    #'   a single positive integer for an open-ended range from that offset,
    #'   a single negative integer for the final N bytes, or a length-2
    #'   vector `c(start, end)` with an exclusive end.
    #' @return A raw vector with the data pointed at by the key, or `NULL` if
    #'   the key does not exist.
    get = function(key, prototype = NULL, byte_range = NULL) {
      private$request(key, byte_range)
    },

    #' @description Retrieve the metadata document of the node at `prefix`,
    #'   always presented in Zarr v.3 format.
    #' @param prefix The prefix of the node whose metadata document to retrieve.
    #' @return A list with the metadata, or `NULL` if the prefix does not
    #'   point to a Zarr group or array.
    get_metadata = function(prefix) {
      if (private$.version == 3L) {
        # Root was already read during initialize() - reuse it rather than
        # re-fetching. Every other prefix needs its own zarr.json: unlike
        # zarr_httpstore (which only ever addresses a single node), an S3
        # store's build_hierarchy() walks the whole tree and calls this for
        # every child, so returning the cached root metadata unconditionally
        # here would misreport every array (and every chunk key, once a
        # misclassified array gets recursed into) as the root's node_type.
        if (prefix == '' || prefix == '/')
          return(private$.metadata)
        meta <- private$request(paste0(prefix, 'zarr.json'))
        if (is.null(meta)) return(NULL)
        return(.parse_metadata(rawToChar(meta)))
      }

      if (is.null(private$.metadata$zarr_consolidated_format)) {
        atts <- private$request('.zattrs')
        if (!is.null(atts))
          atts <- .parse_metadata(rawToChar(atts))
        meta <- private$metadata_v2_to_v3(private$.metadata, atts)
      } else {
        nm <- names(private$.metadata$metadata)
        if (prefix == '/') prefix <- ''
        m <- paste0(prefix, '.zgroup')
        if (!(m %in% nm)) {
          m <- paste0(prefix, '.zarray')
          if (!(m %in% nm)) return(NULL)
        }
        meta <- private$metadata_v2_to_v3(private$.metadata$metadata[[m]])

        m <- paste0(prefix, '.zattrs')
        if (m %in% nm) {
          atts <- private$.metadata$metadata[[m]]
          if (length(atts))
            meta$attributes <- atts
        }
      }
      meta
    },

    #' @description Write the metadata document for the node at `prefix`.
    #'   No-op if the store was opened with `read_only = TRUE`.
    #' @param prefix The prefix of the node whose metadata document to write.
    #' @param metadata A list with the Zarr v.3-format metadata to write.
    #' @return Self, invisibly.
    set_metadata = function(prefix, metadata) {
      if (!private$.read_only) {
        metadata <- private$check_cke(metadata)
        key <- paste0(sub('^/', '', prefix), 'zarr.json')
        body <- charToRaw(jsonlite::toJSON(metadata, auto_unbox = TRUE, null = 'null'))
        self$set(key, body)
      }
      invisible(self)
    },

    #' @description Test if `path` is pointing to a Zarr group.
    #' @param path The path to test.
    #' @return `TRUE` if the `path` points to a Zarr group, `FALSE` otherwise.
    is_group = function(path) {
      meta <- self$get_metadata(.path2prefix(path))
      if (is.null(meta)) FALSE
      else if (meta$node_type == 'group') TRUE
      else FALSE
    },

    #' @description Create a new group in the store under `parent`. Errors
    #'   if the store was opened with `read_only = TRUE`.
    #' @param parent Character string. Path of the parent node.
    #' @param name Character string. Name of the new group.
    #' @return A list with the metadata of the newly-created group.
    create_group = function(parent, name) {
      if (private$.read_only)
        stop('Cannot write to a read-only zarr_s3store.', call. = FALSE)
      prefix <- paste0(.path2prefix(parent), name, '/')
      meta <- list(zarr_format = 3L, node_type = 'group', attributes = list())
      self$set_metadata(prefix, meta)
      meta
    },

    #' @description Create a new array in the store under `parent`. As with
    #'   [zarr_httpstore], the abstract interface's `create_array(parent,
    #'   name)` is extended here with an explicit `metadata` argument, since
    #'   array metadata (shape, dtype, chunking, codecs) cannot be inferred
    #'   and must be supplied by the caller. Errors if the store was opened
    #'   with `read_only = TRUE`.
    #' @param parent Character string. Path of the parent node.
    #' @param name Character string. Name of the new array.
    #' @param metadata A list with the Zarr v.3-format array metadata.
    #' @return A list with the metadata of the newly-created array, as written.
    create_array = function(parent, name, metadata) {
      if (private$.read_only)
        stop('Cannot write to a read-only zarr_s3store.', call. = FALSE)
      prefix <- paste0(.path2prefix(parent), name, '/')
      self$set_metadata(prefix, metadata)
      metadata
    }
  ),
  active = list(
    #' @field friendlyClassName (read-only) Name of the class for printing.
    friendlyClassName = function(value) {
      if (missing(value))
        'S3 store'
    },

    #' @field root (read-only) The bucket and prefix of the store, as `s3://`.
    root = function(value) {
      if (missing(value))
        paste0('s3://', private$.bucket, '/', private$.key_prefix)
    },

    #' @field uri (read-only) The URI of the store location, identical to `root`.
    uri = function(value) {
      if (missing(value))
        self$root
    },

    #' @field separator (read-only) The default chunk separator of the store,
    #'   usually a slash '/'.
    separator = function(value) {
      if (missing(value))
        private$.chunk_sep
    }
  )
)

# ====== Helper functions ======================================================

#' List objects/prefixes in an S3 bucket
#'
#' Lists the immediate contents under a prefix in an S3 bucket, without
#' requiring a valid Zarr store to be present at that prefix. Useful for
#' discovering the actual store path(s) within a bucket that hosts multiple
#' datasets, before calling [open_zarr()] or `zarr_s3store$new()`.
#' @param bucket Character string. The S3 bucket name.
#' @param prefix Character string. The prefix to list under. Default `""`.
#' @param region,profile,access_key,secret_key,session_token,endpoint,anonymous,path_style
#'   As in [zarr_s3store]; same credential resolution and anonymous default.
#' @return A character vector of keys/prefixes found immediately below `prefix`.
#' @export
#' @examples
#' # OME test data
#' (prefix <- s3_list_dir("ome-zarr-scivis", region = "us-east-1"))
#'
s3_list_dir <- function(bucket, prefix = '', region = NULL, profile = NULL,
                        access_key = NULL, secret_key = NULL, session_token = NULL,
                        endpoint = NULL, path_style = NULL, anonymous = NULL) {
  if (!requireNamespace('paws.storage', quietly = TRUE))
    stop('Must install package "paws.storage" for this functionality', call. = FALSE) # nocov

  if (is.null(anonymous))
    anonymous <- is.null(profile) && is.null(access_key)
  if (is.null(path_style))
    path_style <- !is.null(endpoint)
  if (is.null(region) && !is.null(endpoint))
    region <- 'us-east-1'  # placeholder; paws.storage requires a region even for non-AWS endpoints

  cfg <- list()
  if (!is.null(region)) cfg$region <- region
  if (!is.null(endpoint)) cfg$endpoint <- endpoint
  if (isTRUE(path_style)) cfg$s3_force_path_style <- TRUE
  if (isTRUE(anonymous)) {
    cfg$credentials <- list(anonymous = TRUE)
  } else if (!is.null(access_key)) {
    cfg$credentials <- list(creds = list(access_key_id = access_key, secret_access_key = secret_key, session_token = session_token))
  } else if (!is.null(profile)) {
    cfg$credentials <- list(profile = profile)
  }

  client <- paws.storage::s3(config = cfg)
  full_prefix <- if (nzchar(prefix)) sub('/*$', '/', prefix) else ''

  keys <- character(0)
  token <- NULL
  repeat {
    args <- list(Bucket = bucket, Prefix = full_prefix, Delimiter = '/')
    if (!is.null(token)) args$ContinuationToken <- token
    res <- do.call(client$list_objects_v2, args)
    keys <- c(keys, vapply(res$CommonPrefixes %||% list(), function(x) x$Prefix, character(1)))
    keys <- c(keys, vapply(res$Contents %||% list(), function(x) x$Key, character(1)))
    if (isTRUE(res$IsTruncated)) token <- res$NextContinuationToken else break
  }
  unique(keys)
}
