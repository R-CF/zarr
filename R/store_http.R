#' Zarr Store for HTTP access
#'
#' @description This class implements a Zarr HTTP store. With this class Zarr
#'   stores on web servers can be read. Only Zarr v.2 is supported currently.
#'
#'   This class performs no sanity checks on any of the arguments passed to the
#'   methods, for performance reasons. Since this class should be accessed
#'   through group and array objects, it is up to that code to ensure that
#'   arguments are valid, in particular keys and prefixes.
#' @docType class
zarr_httpstore <- R6::R6Class('zarr_httpstore',
  inherit = zarr_store,
  cloneable = FALSE,
  private = list(
    .base_url = '.',    # The root of the zarr store as an URL to a server
    .metadata = list(), # The consolidated metadata of the Zarr v.2 store
    .nodes    = '',     # Character vector of group and variable paths, but without the leading slash

    # Request an item from the HTPP store by key. The key must be fully formed
    # to start from the base URL of the store. The content item of the response
    # is returned as a raw vector.
    request = function(key) {
      url <- paste(private$.base_url, key, sep = '/')
      req <- curl::curl_fetch_memory(url)
      if (req$status_code == 200)
        req$content
      else if (req$status_code == 404)
        NULL
      else
        stop(paste('Error', req$status_code, 'on key', key), call. = FALSE)
    }
  ),
  public = list(
    #' @description Create an instance of this class.
    #'
    #'   HTTP stores are read-only. Currently two types of Zarr store can be
    #'   accessed. A Zarr v.2 consolidated metadata file at the root of the
    #'   store (immediately below the URL) can identify a hierarchy of groups
    #'   and arrays. Alternatively, a store with a single array, either v.2 or
    #'   v.3.
    #' @param url The path to the HTTP store to be opened. The URL may use UTF-8
    #'   code points.
    #' @return An instance of this class.
    initialize = function(url) {
      if (!requireNamespace('curl'))
        stop('Must install package "curl" for this functionality', call. = FALSE) # nocov

      private$.base_url <- sub('/*$', '', url)

      # First attempt: Locate Zarr v.3 array
      meta <- private$request('zarr.json')
      if (!is.null(meta)) {
        private$.metadata <- jsonlite::fromJSON(rawToChar(meta), simplifyDataFrame = FALSE)
        if (private$.metadata$node_type != 'array')
          stop('Cannot read a group from a Zarr v.3 HTTP store.', call. = FALSE)
        format <- private$.metadata$zarr_format
        if (is.null(format) || format != 3L)
          stop('Incompatible "zarr_format" found in the store:', format %||% '(null)', call. = FALSE) # nocov
      } else {
        # Second attempt: Locate Zarr v.2 array
        meta <- private$request('.zarray')
        if (!is.null(meta)) {
          private$.metadata <- jsonlite::fromJSON(rawToChar(meta), simplifyDataFrame = FALSE)
          format <- private$.metadata$zarr_format
          if (is.null(format) || format != 2L)
            stop('Incompatible "zarr_format" found in the store:', format %||% '(null)', call. = FALSE) # nocov
        } else {
          # Final attempt: Retrieve the consolidated metadata
          meta <- private$request('.zmetadata')
          if (is.null(meta))
            stop('No compatible store found at ', url, call. = FALSE)
          meta <- jsonlite::fromJSON(rawToChar(meta), simplifyDataFrame = FALSE)
          if (meta$zarr_consolidated_format != 1L)
            stop('Unsupported version of consolidated metadata.', call. = FALSE)
          private$.metadata <- meta$metadata

          # The groups and arrays in the store as node paths
          private$.nodes <- unique(sub('/\\.z[a-z]+$', '', names(private$.metadata)))
          private$.nodes <- private$.nodes[!startsWith(private$.nodes, '.z')]

          format <- private$.metadata$.zgroup$zarr_format
          if (is.null(format) || format != 2L)
            stop('Incompatible "zarr_format" found in the store:', format %||% '(null)', call. = FALSE) # nocov
        }
      }

      super$initialize(read_only = TRUE, version = format)
    },

    #' @description Check if a key exists in the store. The key can point to a
    #'   group, an array, or a metadata file.
    #' @param key Character string. The key that the store will be searched for.
    #' @return `TRUE` if argument `key` is found, `FALSE` otherwise.
    exists = function(key) {
      key %in% private$.nodes || key %in% names(private$.metadata)
    },

    #' @description Clearing the store is not supported.
    #' @return `FALSE`.
    clear = function() {
      FALSE
    },

    #' @description Removing a key from the store is not supported.
    #' @param key Ignored.
    #' @return `FALSE`.
    erase = function(key) {
      FALSE
    },

    #' @description Removing keys from the store is not supported.
    #' @param prefix Ignored.
    #' @return `FALSE`.
    erase_prefix = function(prefix) {
      FALSE
    },

    #' @description Retrieve all keys and prefixes with a given prefix and which
    #'   do not contain the character "/" after the given prefix. In other
    #'   words, this retrieves all the nodes in the store below the node
    #'   indicated by the prefix.
    #' @param prefix Character string. The prefix whose nodes to list.
    #' @return A character array with all keys found in the store immediately
    #'   below the `prefix`, both for groups and arrays.
    list_dir = function(prefix) {
      keys <- private$.nodes[startsWith(private$.nodes, prefix)]
      # FIXME: Test that the keys are indeed nodes, i.e. have a file 'zarr.json'.
      keys
    },

    #' @description Retrieve all keys and prefixes with a given prefix.
    #' @param prefix Character string. The prefix whose nodes to list.
    #' @return A character vector with all paths found in the store below the
    #'   `prefix` location, both for groups and arrays.
    list_prefix = function(prefix) {
      nm <- names(private$.metadata)
      keys <- nm[startsWith(nm, prefix)]
      # FIXME: Test that the keys are indeed nodes, i.e. have a file 'zarr.json'.
      paste0('/', keys)
    },

    #' @description Storing a `(key, value)` pair is not supported.
    #' @param key Ignored.
    #' @param value Ignored.
    #' @return Self, invisibly.
    set = function(key, value) {
      invisible(self)
    },

    #' @description Storing a `(key, value)` pair is not supported.
    #' @param key Ignored.
    #' @param value Ignored.
    #' @return Self, invisibly.
    set_if_not_exists = function(key, value) {
      invisible(self)
    },

    #' @description Retrieve the value associated with a given key.
    #' @param key Character string. The key for which to get data.
    #' @param prototype Ignored. The only buffer type that is supported maps
    #'   directly to an R raw vector.
    #' @param byte_range Ignored. The full data value is always returned.
    #' @return A raw vector with the data pointed at by the key.
    get = function(key, prototype = NULL, byte_range = NULL) {
      private$request(key)
    },

    #' @description Retrieve the metadata document of the node at the location
    #'   indicated by the `prefix` argument. The metadata will always be
    #'   presented to the caller in the Zarr v.3 format. Attributes, if present,
    #'   will be added.
    #' @param prefix The prefix of the node whose metadata document to retrieve.
    #' @return A list with the metadata, or `NULL` if the prefix is not pointing
    #'   to a Zarr group or array.
    get_metadata = function(prefix) {
      if (private$.version == 3L)
        # v.3 so a single array
        return(private$.metadata)

      # v.2
      if (is.null(private$.metadata$zarr_consolidated_format)) {
        # Store holds a single array
        meta <- private$metadata_v2_to_v3(private$.metadata)
        # Attributes
        atts <- private$request('.zattrs')
        if (!is.null(atts)) {
          atts <- jsonlite::fromJSON(rawToChar(atts), simplifyDataFrame = FALSE)
          meta$attributes <- atts
        }
      } else {
        # Consolidated metadata
        nm <- names(private$.metadata)
        if (prefix == '/') prefix <- ''
        m <- paste0(prefix, '.zgroup')
        if (!(m %in% nm)) {
          m <- paste0(prefix, '.zarray')
          if (!(m %in% nm)) return(NULL)
        }
        meta <- private$metadata_v2_to_v3(private$.metadata[[m]])

        # Add any attributes
        m <- paste0(prefix, '.zattrs')
        if (m %in% nm) {
          atts <- private$.metadata[[m]]
          if (length(atts))
            meta$attributes <- atts
        }
      }
      meta
    },

    #' @description Setting metadata is not supported.
    #' @param prefix Ignored.
    #' @param metadata Ignored.
    #' @return Self, invisible
    set_metadata = function(prefix, metadata) {
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

    #' @description Creating a new group in the store is not supported.
    #' @param path,name Ignored.
    #' @return An error indicating that the group could not be created.
    create_group = function(path, name) {
      stop('Cannot write new objects to a Zarr HTTP store.', call. = FALSE) # nocov
    },

    #' @description Creating a new array in the store is not supported.
    #' @param parent,name,metadata Ignored.
    #' @return An error indicating that the array could not be created.
    create_array = function(parent, name, metadata) {
      stop('Cannot write new objects to a Zarr HTTP store.', call. = FALSE) # nocov
    }
  ),
  active = list(
    #' @field friendlyClassName (read-only) Name of the class for printing.
    friendlyClassName = function(value) {
      if (missing(value))
        'HTTP store'
    },

    #' @field root (read-only) The root of the HTTP store, identical to its URL.
    root = function(value) {
      if (missing(value))
        private$.base_url
    },

    #' @field uri (read-only) The URI of the store location.
    uri = function(value) {
      if (missing(value))
        private$.base_url
    },

    #' @field separator (read-only) The default chunk separator of the store,
    #'   usually a slash '/'.
    separator = function(value) {
      if (missing(value))
        private$.chunk_sep
    }
  )
)
