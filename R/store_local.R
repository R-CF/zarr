#' Zarr Store for the Local File System
#'
#' @description This class implements a Zarr store for the local file system.
#' With this class Zarr stores on devices accessible through the local file
#' system can be read and written to. This includes locally attached drives,
#' removable media, NFS mounts, etc.
#'
#' The chunking pattern is to locate all the chunks in a single directory. That
#' means that chunks have names like "c0.0.0" in the array directory.
#'
#' This class performs no sanity checks on any of the arguments passed to the
#' methods, for performance reasons. Since this class should be accessed through
#' group and array objects, it is up to that code to ensure that arguments are
#' valid, in particular keys and prefixes.
#' @references https://zarr-specs.readthedocs.io/en/latest/v3/stores/filesystem/index.html
#' @docType class
zarr_localstore <- R6::R6Class('zarr_localstore',
  inherit = zarr_store,
  cloneable = FALSE,
  private = list(
    .root = '/'    # The root of the zarr store as a file system path
  ),
  public = list(
    #' @description Create an instance of this class.
    #'
    #'   If the location is not currently a Zarr store, it will be created,
    #'   unless argument `metadata = NULL`. This will write the `metadata` as a
    #'   small JSON file to the `root` location, identifying the location as a
    #'   Zarr store, possibly for a single array.
    #'
    #'   The location on the file system must be writable by the process opening
    #'   or creating the store.
    #' @param root The path to the local store to be created or opened. The path
    #'   may use UTF-8 code points. Following the Zarr specification, it is
    #'   recommended that the root path has an extension of ".zarr" to easily
    #'   identify the location as a Zarr store. When creating a file store, the
    #'   root directory cannot already exist.
    #' @param read_only Flag to indicate if the store is opened read-only.
    #'   Default `FALSE`.
    #' @param metadata Optional. A list with the metadata of the object to
    #'   create at the root of a new store, either a Zarr group or a Zarr array.
    #'   Default is `NULL` which means that an existing store is opened. To
    #'   create a new store, supply this argument. It is an error to supply a
    #'   `metadata` document for an existing Zarr store.
    #' @return An instance of this class.
    initialize = function(root, read_only = FALSE, metadata = NULL) {
      root <- suppressWarnings(normalizePath(uri_to_path(root)))
      have_root <- dir.exists(root)
      meta_path <- file.path(root, 'zarr.json')

      if (is.null(metadata)) {
        # Opening an existing store
        if (!have_root)
          stop('No Zarr store at the root location.', call. = FALSE) # nocov
        if (file.exists(meta_path)) {
          meta <- jsonlite::fromJSON(meta_path)
          format <- meta$zarr_format
          if (is.null(format) || !format %in% c(2, 3))
            stop('Incompatible "zarr_format" found in the store:', format, call. = FALSE) # nocov
        }
      } else {
        # Create a new store
        if (have_root)
          stop('Location for new Zarr store already exists.', call. = FALSE) # nocov
        dir.create(root, recursive = TRUE, mode = '0771')
        jsonlite::write_json(metadata, path = meta_path, pretty = T, auto_unbox = TRUE)
        format <- metadata$zarr_format
      }

      super$initialize(read_only, version = format)
      private$.root <- root
      private$.supports_writes <- TRUE
      private$.supports_consolidated_metadata = FALSE
    },

    #' @description Check if a key exists in the store. The key can point to a
    #'   group, an array, or a chunk.
    #' @param key Character string. The key that the store will be searched for.
    #' @return `TRUE` if argument `key` is found, `FALSE` otherwise.
    exists = function(key) {
      file.exists(file.path(private$.root, key))
    },

    #' @description Clear the store. Remove all keys and values from the store.
    #'   Invoking this method deletes affected files on the file system and this
    #'   action can not be undone. The only file that will remain is "zarr.json"
    #'   in the root of this store.
    #' @return Self, invisibly.
    clear = function() {
      # files <- rev(list.files(private$.root, all.files = TRUE, recursive = TRUE, include.dirs = TRUE))
      unlink(paste0(private$.root, '/*'), recursive = TRUE)
      jsonlite::write_json(list(zarr_format = jsonlite::unbox(3), node_type = jsonlite::unbox("group")),
                           path = file.path(private$.root, 'zarr.json'), pretty = T)
      invisible(self)
    },

    #' @description Remove a key from the store. The key typically points to an
    #'   array but could also point to a group or a chunk. The location of the
    #'   key itself is also removed.
    #' @param key Character string. The item to remove from the store.
    #' @return Self, invisibly.
    erase = function(key) {
      unlink(file.path(private$.root, key))
      invisible(self)
    },

    #' @description Remove all keys and prefixes in the store that begin with a
    #'   given prefix. The last location in the prefix is preserved while all
    #'   keys below are removed from the store.
    #' @param prefix Character string. The prefix to groups or arrays to remove
    #'   from the store, including in child groups.
    #' @return Self, invisibly.
    erase_prefix = function(prefix) {
      unlink(file.path(private$.root, paste0(prefix, "*")), recursive = TRUE)
      prefix <- substr(prefix, 1L, nchar(prefix) - 1L)
      jsonlite::write_json(list(zarr_format = jsonlite::unbox(3), node_type = jsonlite::unbox("group")),
                           path = file.path(private$.root, prefix, 'zarr.json'), pretty = T)
      invisible(self)
    },

    #' @description Retrieve all keys and prefixes with a given prefix and which
    #'   do not contain the character "/" after the given prefix. This method is
    #'   part of the abstract store interface in ZEP0001. In other words, this
    #'   retrieves all the nodes in the store below the node indicated by the
    #'   prefix.
    #' @param prefix Character string. The prefix to nodes to list.
    #' @return A character array with all keys found in the store immediately
    #'   below the `prefix`, both for groups and arrays.
    list_dir = function(prefix) {
      keys <- list.dirs(file.path(private$.root, prefix), full.names = FALSE, recursive = FALSE)
      # FIXME: Test that the keys are indeed nodes, i.e. have a file 'zarr.json'.
      keys
    },

    #' @description Retrieve all keys and prefixes with a given prefix. This
    #'   method is part of the abstract store interface in ZEP0001.
    #' @param prefix Character string. The prefix to nodes to list.
    #' @return A character vector with all paths found in the store below the
    #'   `prefix` location, both for groups and arrays.
    list_prefix = function(prefix) {
      keys <- list.dirs(file.path(private$.root, prefix), full.names = FALSE, recursive = TRUE)[-1L] # exclude prefix itself
      # FIXME: Test that the keys are indeed nodes, i.e. have a file 'zarr.json'.
      paste0('/', keys)
    },

    #' @description Store a `(key, value)` pair. The key points to a specific
    #'   file (shard or chunk of an array) in a store, rather than a group or an
    #'   array. The key must be relative to the root of the store (so not start
    #'   with a "/") and may be composite. It must include the name of the file.
    #'   An example would be "group/subgroup/array/c0.0.0". The group hierarchy
    #'   and the array must have been created before. If the `value` exists, it
    #'   will be overwritten.
    #' @param key The key whose value to set.
    #' @param value The value to set, a complete chunk of data.
    #' @return Self, invisibly, or an error.
    set = function(key, value) {
      f <- file(file.path(private$.root, key), 'w+b')
      writeBin(value, f)
      close(f)
      invisible(self)
    },

    #' @description Store a `(key, value)` pair. The key points to a specific
    #'   file (shard or chunk of an array) in a store, rather than a group or an
    #'   array. The key must be relative to the root of the store (so not start
    #'   with a "/") and may be composite. It must include the name of the file.
    #'   An example would be "group/subgroup/array/c0.0.0". The group hierarchy
    #'   and the array must have been created before. If the `value` exists,
    #'   nothing will be written.
    #' @param key The key whose value to set.
    #' @param value The value to set, a complete chunk of data.
    #' @return Self, invisibly, or an error.
    set_if_not_exists = function(key, value) {
      path <- file.path(private$.root, key)
      if (!file.exists(path)) {
        f <- file(path, 'w+b')
        writeBin(value, f)
        close(f)
      }
      invisible(self)
    },

    #' @description Retrieve the value associated with a given key. This method
    #'   is part of the abstract store interface in ZEP0001.
    #' @param key Character string. The key for which to get data.
    #' @param prototype Ignored. The only buffer type that is supported maps
    #'   directly to an R raw vector.
    #' @param byte_range If `NULL`, all data associated with the key is
    #'   retrieved. If a single positive integer, all bytes starting from a
    #'   given byte offset to the end of the object are returned. If a single
    #'   negative integer, the final bytes are returned. If an integer vector of
    #'   length 2, request a specific range of bytes where the end is exclusive.
    #'   If the range ends after the end of the object, the entire remainder of
    #'   the object will be returned. If the given range is zero-length or
    #'   starts after the end of the object, an error will be returned.
    #' @return An raw vector of data, or `NULL` if no data was found.
    get = function(key, prototype, byte_range) {
      f <- file.path(self$root, key)
      if(!file.exists(f)) return(NULL)

      sz <- file.info(f)$size
      if (is.null(byte_range)) {
        start <- 0L
        n <- sz
      } else {
        start <- byte_range[1L]
        if (start > sz)
          stop('Byte-range of request is invalid.', call. = FALSE) # nocov
        if (length(byte_range) == 1L) {
          if (start >= 0L) {
            # Read to the end
            n <- sz - start
          } else {
            # Position from the end, read the rest
            start <- sz + start
            n <- sz - start
          }
        } else {
          n <- min(byte_range[2L], sz) - start
        }
      }
      if (n < 1L)
        stop('Byte-range of request is invalid.', call. = FALSE) # nocov

      f <- file(f, 'rb')
      on.exit(close(f))
      if (start > 0L)
        seek(f, where = start, origin = 'start')
      raw <- readBin(f, what = 'raw', n = n)
      return(raw)
    },

    #' @description Retrieve the metadata document of the node at the location
    #' indicated by the `path` argument.
    #' @param path The path of the node whose metadata document to retrieve.
    #' @return A list with the metadata, or `NULL` if the path is not pointing
    #' to a Zarr group or array.
    get_metadata = function(path) {
      fn <- file.path(private$.root, path, 'zarr.json')
      if (file.exists(fn))
        jsonlite::fromJSON(fn, simplifyDataFrame = FALSE)
      else
        NULL
    },

    #' @description Test if `path` is pointing to a Zarr group.
    #' @param path The path to test.
    #' @return `TRUE` if the `path` points to a Zarr group, `FALSE` otherwise.
    is_group = function(path) {
      meta <- self$get_metadata(path)
      if (is.null(meta)) FALSE
      else if (meta$node_type == 'group') TRUE
      else FALSE
    },

    #' @description Create a new group in the store under the specified path.
    #'   The `path` must point to a Zarr group.
    #' @param path The path to the parent group of the new group.
    #' @param name The name of the new group.
    #' @return A list with the metadata of the group, or an error if the group
    #'   could not be created.
    create_group = function(path, name) {
      if (private$.read_only)
        stop('Cannot write new objects to the Zarr store.', call. = FALSE) # nocov

      if (!self$is_group(path))
        stop('Path does not point to a Zarr group: ', path, call. = FALSE) # nocov

      # Create the sub-group
      fp <- file.path(private$.root, path, name)
      if (dir.create(fp, showWarnings = FALSE, recursive = FALSE, mode = '0771')) {
        meta <- list(zarr_format = 3, node_type = 'group')
        jsonlite::write_json(meta, path = file.path(fp, 'zarr.json'), auto_unbox = TRUE, pretty = T)
        meta
      } else
        stop('Could not create a group at path: ', fp, call. = FALSE) # nocov
    },

    #' @description Create a new array in the store under the specified path to
    #'   the `parent` argument. The `parent` path must point to a Zarr group.
    #' @param parent The path to the parent group of the new array.
    #' @param name The name of the new array.
    #' @param metadata A `list` with the metadata for the array. The list has to
    #'   be valid for array construction. Use the [array_builder] class to
    #'   create and or test for validity.
    #' @return A list with the metadata of the array, or an error if the array
    #'   could not be created.
    create_array = function(parent, name, metadata) {
      if (private$.read_only)
        stop('Cannot write new objects to the Zarr store.', call. = FALSE) # nocov

      if (!self$is_group(parent))
        stop('Path does not point to a Zarr group: ', parent, call. = FALSE) # nocov

      # Create the array
      parent <- substring(parent, 2L)
      fp <- file.path(private$.root, parent, name)
      if (dir.create(fp, showWarnings = FALSE, recursive = FALSE, mode = '0771')) {
        jsonlite::write_json(metadata, path = file.path(fp, 'zarr.json'), auto_unbox = TRUE, pretty = T)
        metadata
      } else
        stop('Could not create an array at path: ', fp, call. = FALSE) # nocov
    }
  ),
  active = list(
    #' @field friendlyClassName (read-only) Name of the class for printing.
    friendlyClassName = function(value) {
      if (missing(value))
        'Local file system store'
    },

    #' @field root (read-only) The root directory of the file system store.
    root = function(value) {
      if (missing(value))
        private$.root
    },

    #' @field uri (read-only) The URI of the store location.
    uri = function(value) {
      if (missing(value))
        path_to_uri(private$.root)
    }
  )
)
