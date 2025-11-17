#' In-memory Zarr Store
#'
#' @description This class implements a Zarr store in RAM memory. With this
#'   class Zarr stores can be read and written to. Obviously, any data is not
#'   persisted after the memory store is de-referenced and garbage-collected.
#'
#'   All data is stored in a list. The Zarr array itself has a list with the
#'   metadata, its chunks have names like "c.0.0.0" and they have an R
#'   array-like value.
#'
#'   This class performs no sanity checks on any of the arguments passed to the
#'   methods, for performance reasons. Since this class should be accessed
#'   through group and array objects, it is up to that code to ensure that
#'   arguments are valid, in particular keys and prefixes.
#' @docType class
zarr_memorystore <- R6::R6Class('zarr_memorystore',
  inherit = zarr_store,
  cloneable = FALSE,
  private = list(
    # A list of keys in the store.
    .keys = list()
  ),
  public = list(
    #' @description Create an instance of this class.
    #' @return An instance of this class.
    initialize = function() {
      super$initialize(read_only = FALSE, version = 3L)
      private$.supports_consolidated_metadata = FALSE
    },

    #' @description Check if a key exists in the store. The key can point to a
    #'   group, an array (having a metadata list as its value) or a chunk.
    #' @param key Character string. The key that the store will be searched for.
    #' @return `TRUE` if argument `key` is found, `FALSE` otherwise.
    exists = function(key) {
      key %in% names(private$.keys)
    },

    #' @description Clear the store. Remove all keys and values from the store.
    #'   Invoking this method deletes all data and this action can not be
    #'   undone.
    #' @return `TRUE`. This operation always proceeds successfully once invoked.
    clear = function() {
      private$.keys <- list()
      TRUE
    },

    #' @description Remove a key from the store. The key must point to an array
    #'   or a chunk. If the key points to an array, the key and all of
    #'   subordinated keys are removed.
    #' @param key Character string. The key to remove from the store.
    #' @return `TRUE`. This operation always proceeds successfully once invoked,
    #' even if argument `key` does not point to an existing key.
    erase = function(key) {
      private$.keys[!startsWith(names(private$.keys), key)]
      TRUE
    },

    #' @description Remove all keys in the store that begin with a given prefix.
    #' @param prefix Character string. The prefix to groups or arrays to remove
    #'   from the store, including in child groups.
    #' @return `TRUE`. This operation always proceeds successfully once invoked,
    #' even if argument `prefix` does not point to any existing keys.
    erase_prefix = function(prefix) {
      private$.keys[!startsWith(names(private$.keys), prefix)]
      TRUE
    },

    #' @description Retrieve all keys with a given prefix and which do not
    #'   contain the character "/" after the given prefix. In other words, this
    #'   retrieves all the keys in the store below the key indicated by the
    #'   prefix.
    #' @param prefix Character string. The prefix whose nodes to list.
    #' @return A character array with all keys found in the store immediately
    #'   below the `prefix`.
    list_dir = function(prefix) {
      if (nzchar(prefix)) {
        keys <- names(private$.keys)
        keys[startsWith(keys, prefix)]
      } else character(0)
    },

    #' @description Retrieve all keys and prefixes with a given prefix.
    #' @param prefix Character string. The prefix to nodes to list.
    #' @return A character vector with all paths found in the store below the
    #'   `prefix` location.
    list_prefix = function(prefix) {
      keys <- names(private$.keys)
      keys[startsWith(keys, prefix)]
    },

    #' @description Store a `(key, value)` pair. If the `value` exists, it will
    #'   be overwritten.
    #' @param key The key whose value to set.
    #' @param value The value to set, typically a complete chunk of data, a
    #'   `raw` vector.
    #' @return Self, invisibly.
    set = function(key, value) {
      private$.keys[key] <- list(value)
      invisible(self)
    },

    #' @description Store a `(key, value)` pair. If the `key` exists, nothing
    #'   will be written.
    #' @param key The key whose value to set.
    #' @param value The value to set, a complete chunk of data.
    #' @return Self, invisibly, or an error.
    set_if_not_exists = function(key, value) {
      if (!(key %in% names(private$.keys)))
        private$.keys[key] <- list(value)
      invisible(self)
    },

    #' @description Retrieve the value associated with a given key.
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
    get = function(key, prototype = NULL, byte_range = NULL) {
      value <- private$.keys[[key]]
      if (is.null(value)) return(NULL)

      sz <- length(value)
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

      return(value[start:(start + n - 1L)])
    },

    #' @description Retrieve the metadata document at the location indicated by
    #'   the `prefix` argument.
    #' @param prefix The prefix whose metadata document to retrieve.
    #' @return A list with the metadata, or `NULL` if the prefix is not pointing
    #'   to a Zarr array.
    get_metadata = function(prefix) {
      key <- if (prefix == '/') 'root' else .prefix2key(prefix)
      private$.keys[[key]]
    },

    #' @description Create a new group in the store under the specified path.
    #' @param path The path to the parent group of the new group. Ignored when
    #'   creating a root group.
    #' @param name The name of the new group. This may be an empty string `""`
    #'   to create a root group. It is an error to supply an empty string if a
    #'   root group or array already exists.
    #' @return A list with the metadata of the group, or an error if the group
    #'   could not be created.
    create_group = function(path, name) {
      meta <- list(zarr_format = 3, node_type = 'group')

      if (nzchar(name)) {
        # Adding a sub-group
        path <- .path2key(path)
        key <- if (nzchar(path)) {
          if (!(path %in% names(private$.keys)))
            stop('Path does not point to a Zarr group: ', path, call. = FALSE) # nocov
          paste(path, name, sep = '/')
        } else name
        if (key %in% names(private$.keys))
          stop('Key already exists in the store: ', key, call. = FALSE) # nocov
        private$.keys[[key]] <- meta
      } else
        # Adding the root group
        private$.keys <- list(root = meta)
      meta
    },

    #' @description Create a new array in the store under key constructed from
    #'   the specified path to the `parent` argument and the `name`. The key may
    #'   not already exist in the store.
    #' @param parent The path to the parent group of the new array. This is
    #' ignored if the `name` argument is the empty string.
    #' @param name The name of the new array.
    #' @param metadata A `list` with the metadata for the array. The list has to
    #'   be valid for array construction. Use the [array_builder] class to
    #'   create and or test for validity. An element "chunk_key_encoding" will
    #'   be added to the metadata if it not already there or contains an invalid
    #'   separator.
    #' @return A list with the metadata of the array, or an error if the array
    #'   could not be created.
    create_array = function(parent, name, metadata) {
      cke <- metadata[['chunk_key_encoding']]
      if (is.null(cke) || !(cke$configuration$separator %in% c('.', '/')))
        metadata[['chunk_key_encoding']] <- list(name = 'default',
                                                 configuration = list(separator = private$.chunk_sep))

      if (nzchar(name)) {
        # Adding an array to a group
        path <- .path2key(parent)
        key <- if (nzchar(path)) {
          if (!(path %in% names(private$.keys)))
            stop('Path does not point to a Zarr group: ', path, call. = FALSE) # nocov
          paste(path, name, sep = '/')
        } else name
        if (key %in% names(private$.keys))
          stop('Key already exists in the store: ', key, call. = FALSE) # nocov
        private$.keys[key] <- list(metadata)
      } else
        # Adding an array as the root
        private$.keys <- list(root = metadata)

      metadata
    }
  ),
  active = list(
    #' @field friendlyClassName (read-only) Name of the class for printing.
    friendlyClassName = function(value) {
      if (missing(value))
        'memory store'
    },

    #' @field separator (read-only) The separator of the memory store,
    #'   always a dot '.'.
    separator = function(value) {
      if (missing(value)) '.'
    },

    #' @field keys (read-only) The defined keys in the store.
    keys = function(value) {
      if (missing(value))
        private$.keys
    }
  )
)
