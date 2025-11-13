#' @import methods
#' @import R6
#' @import jsonlite
NULL

#' Zarr Abstract Store
#'
#' @description This class implements a Zarr abstract store. It provides the
#'   basic plumbing for specific implementations of a Zarr store. It implements
#'   the Zarr abstract store interface, with some extensions from the Python
#'   `zarr.abc.store.Store` abstract class. Functions `set_partial_values()` and
#'   `get_partial_values()` are not implemented.
#'
#' @references
#'   https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html#abstract-store-interface
#' @docType class
zarr_store <- R6::R6Class('zarr_store',
  cloneable = FALSE,
  private = list(
    # From the abstract store specification
    .read_only = FALSE,                      # Flag to indicate if the store is read-only.
    .supports_consolidated_metadata = TRUE,  # Flag to indicate if the store can consolidate metadata.
    .supports_deletes = TRUE,                # Flag to indicate if keys and arrays can be deleted.
    .supports_listing = TRUE,                # Flag to indicate if the store can list its keys.
    .supports_writes = TRUE,                 # Flag to indicate if the store can write data.

    # Local properties
    .version = 3L  # The zarr version, by default 3
  ),
  public = list(
    #' @description Create an instance of this class. Since this class is
    #'   "abstract", it should not be instantiated directly - it is intended to
    #'   be called by descendant classes, exclusively.
    #' @param read_only Flag to indicate if the store is read-only. Default
    #'   `FALSE`.
    #' @param version The version of the Zarr store. By default this is 3.
    #' @return An instance of this class.
    initialize = function(read_only = FALSE, version = 3L) {
      private$.read_only <- read_only
      private$.version <- version
    },

    #' @description Clear the store. Remove all keys and values from the store.
    #' @return Self, invisibly.
    clear = function() {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Remove a key from the store. This method is part of the
    #'   abstract store interface in ZEP0001.
    #' @param key Character string. The key to remove from the store.
    #' @return Self, invisibly.
    erase = function(key) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Remove all keys and prefixes in the store that begin with a
    #'   given prefix. This method is part of the abstract store interface in
    #'   ZEP0001.
    #' @param prefix Character string. The prefix to groups or arrays to remove
    #'   from the store, including in child groups.
    #' @return Self, invisibly.
    erase_prefix = function(prefix) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Check if a key exists in the store.
    #' @param key Character string. The key that the store will be searched for.
    #' @return `TRUE` if argument `key` is found, `FALSE` otherwise.
    exists = function(key) {
      stop('Class', class(self)[1L], 'must implement this method.')
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
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Return the size, in bytes, of a value in a Store.
    #' @param key Character string. The key whose length will be returned.
    #' @return The size, in bytes, of the object.
    getsize = function(key) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Return the size, in bytes, of all objects found under the
    #'   group indicated by the prefix.
    #' @param prefix Character string. The prefix to groups to scan.
    #' @return The size, in bytes, of all the objects under a group, as a
    #'   single integer value.
    getsize_prefix = function(prefix) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Is the group empty?
    #' @param prefix Character string. The prefix to the group to scan.
    #' @return `TRUE` is the group indicated by argument `prefix` has no
    #'   sub-groups or arrays, `FALSE` otherwise.
    is_empty = function(prefix) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Retrieve all keys in the store. This method is part of the
    #'   abstract store interface in ZEP0001.
    #' @return A character vector with all keys found in the store, both for
    #'   groups and arrays.
    list = function() {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Retrieve all keys and prefixes with a given prefix and which
    #'   do not contain the character "/" after the given prefix. This method is
    #'   part of the abstract store interface in ZEP0001.
    #' @param prefix Character string. The prefix to groups to list.
    #' @return A list with all keys found in the store immediately below the
    #'   `prefix`, both for groups and arrays.
    list_dir = function(prefix) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Retrieve all keys and prefixes with a given prefix. This
    #'   method is part of the abstract store interface in ZEP0001.
    #' @param prefix Character string. The prefix to groups to list.
    #' @return A character vector with all fully-qualified keys found in the
    #'   store, both for groups and arrays.
    list_prefix = function(prefix) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Store a (key, value) pair.
    #' @param key The key whose value to set.
    #' @param value The value to set, typically a chunk of data.
    #' @return Self, invisibly.
    set = function(key, value) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Store a key to argument `value` if the key is not already
    #'   present. This method is part of the abstract store interface in
    #'   ZEP0001.
    #' @param key The key whose value to set.
    #' @param value The value to set, typically an R array.
    #' @return Self, invisibly.
    set_if_not_exists = function(key, value) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Retrieve the metadata document of the node at the location
    #'   indicated by the `prefix` argument.
    #' @param prefix The prefix of the node whose metadata document to retrieve.
    get_metadata = function(prefix) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Set the metadata document of the node at the location
    #'   indicated by the `prefix` argument. This is a no-op for stores that
    #'   have no writing capability. Other stores must override this method.
    #' @param prefix The prefix of the node whose metadata document to set.
    #' @param metadata The metadata to persist, either a `list` or an instance
    #' of [array_builder].
    #' @return Self, invisible
    set_metadata = function(prefix, metadata) {
      invisible(self)
    },

    #' @description Create a new group in the store under the specified path to
    #'   the `parent` argument. The `parent` path must point to a Zarr group.
    #' @param parent The path to the parent group of the new group.
    #' @param name The name of the new group.
    #' @return A list with the metadata of the group, or an error if the group
    #'   could not be created.
    create_group = function(parent, name) {
      stop('Class', class(self)[1L], 'must implement this method.')
    },

    #' @description Create a new array in the store under the specified path to
    #'   the `parent` argument. The `parent` path must point to a Zarr group.
    #' @param parent The path to the parent group of the new array.
    #' @param name The name of the new array.
    #' @return A list with the metadata of the array, or an error if the array
    #'   could not be created.
    create_array = function(parent, name) {
      stop('Class', class(self)[1L], 'must implement this method.')
    }
  ),
  active = list(
    #' @field friendlyClassName (read-only) Name of the class for printing.
    friendlyClassName = function(value) {
      if (missing(value))
        'Abstract store interface'
    },

    #' @field read_only (read-only) Flag to indicate if the store is read-only.
    read_only = function(value) {
      if (missing(value))
        private$.read_only
    },

    #' @field supports_consolidated_metadata Flag to indicate if the store can
    #'   consolidate metadata.
    supports_consolidated_metadata = function(value) {
      if (missing(value))
        private$.supports_consolidated_metadata
    },

    #' @field supports_deletes Flag to indicate if keys and arrays can be
    #'   deleted.
    supports_deletes = function(value) {
      if (missing(value))
        private$.supports_deletes
    },

    #' @field supports_listing Flag to indicate if the store can list its keys.
    supports_listing = function(value) {
      if (missing(value))
        private$.supports_listing
    },

    #' @field supports_partial_writes Deprecated, always `FALSE`.
    supports_partial_writes = function(value) {
      FALSE
    },

    #' @field supports_writes Flag to indicate if the store can write data.
    supports_writes = function(value) {
      if (missing(value))
        private$.supports_writes
    },

    #' @field version (read-only) The Zarr version of the store.
    version = function(value) {
      if (missing(value))
        private$.version
    },

    #' @field separator (read-only) The separator of the store, a slash '/' by
    #'   default. Sub-classes may override this.
    separator = function(value) {
      if (missing(values)) '/'
    }
  )
)
