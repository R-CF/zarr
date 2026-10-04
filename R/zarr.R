#' Zarr object
#'
#' @description This class implements a Zarr object. A Zarr object is a set of
#'   objects that make up an instance of a Zarr data set, irrespective of where
#'   it is located. The Zarr object manages the hierarchy as well as the
#'   underlying store.
#'
#'   A Zarr object may contain multiple Zarr arrays in a hierarchy. The main
#'   class for managing Zarr arrays is [zarr_array]. The hierarchy is made up of
#'   [zarr_group] instances. Each `zarr_array` is located in a `zarr_group`.
#' @docType class
#' @export
zarr <- R6::R6Class("zarr",
  private = list(
    .store = NULL,

    .root = NULL,

    .domain = NULL # The Zarr domain managing this zarr instance
  ),
  public = list(
    #' @description Create a new Zarr instance. The Zarr instance manages the
    #'   groups and arrays in the Zarr store that it refers to. This instance
    #'   provides access to all objects in the Zarr store.
    #'
    #'   This method can open any Zarr store located on systems with a supported
    #'   protocol ('local', 's3', 'http').
    #'
    #'   This method can also create a new Zarr store on a local file system or
    #'   in memory. It is not possible to create a new store on S3 or an a web
    #'   server. The newly created store is uninitialised, it is an empty
    #'   directory. Either assign a [zarr_array] to the `root` field, or create
    #'   a root [zarr_group] to make the store valid and usable.
    #' @param store Optional. Either an instance of a [zarr_store] descendant
    #'   class where the Zarr objects are located, or character string that
    #'   indicates a location on a file system or a HTTP or S3 server where the
    #'   Zarr store is to be found. The character string may contain UTF-8
    #'   characters and/or use a file URI format. On a local file system the
    #'   Zarr store will be created if it does not exist. If omitted, an
    #'   in-memory Zarr store will be created.
    #' @param read_only Optional. Logical that indicates if the store is to be
    #'   opened in read-only mode. Default is ` NULL`, which implies `FALSE` for
    #'   a local file system and memory store, `TRUE` otherwise.
    #' @param protocol Optional, character string. Override automatic protocol
    #'   detection ('local', 'http', or 's3'). Needed for S3-compatible
    #'   endpoints that aren't AWS and don't follow AWS's hostname conventions
    #'   (MinIO, EMBASSY Cloud, Ceph RGW, etc.) - there's no reliable way to
    #'   recognize these from the URL alone, you have to indicate so explicitly
    #'   rather than have this method parse the location.
    #' @param ... Additional protocol-specific parameters passed through to the
    #'   underlying store constructor. For `s3://` and S3 `https://` locations,
    #'   this includes `region`, `profile`, `access_key`/`secret_key`/
    #'   `session_token`, `endpoint`, and `anonymous` — see [zarr_s3store].
    #'   Ignored for memory, local and plain HTTP locations.
    #' @returns A `zarr` object.
    initialize = function(store, read_only = NULL, protocol = NULL, ...) {
      private$.store <- if (missing(store) || is.null(store))
        zarr_memorystore$new()
      else if (inherits(store, 'zarr_store'))
        store
      else if (is.character(store) && length(store) == 1L) {
        protocol <- protocol %||% .protocol(store)
        if (is.null(read_only))
          read_only <- protocol != 'local'

        switch(protocol,
               's3'    = {
                 loc <- .parse_s3_location(store)
                 zarr_s3store$new(bucket = loc$bucket, prefix = loc$prefix,
                                  region = loc$region, endpoint = loc$endpoint,
                                  read_only = read_only, ...)},
               'http'  = zarr_httpstore$new(url = store),
               'local' = zarr_localstore$new(root = store, read_only = read_only),
               stop('Argument `store` points to an unrecognizable location: ', store, call. = FALSE))
      } else
        stop('Argument `store` must be a `zarr_store` instance or a single character string', call. = FALSE)

      # Build the node hierarchy
      metadata <- private$.store$get_metadata('/')
      if (!is.null(metadata)) {
        private$.root <- .buildNode(name = '', metadata = metadata, parent = self)
        if (inherits(private$.root, 'zarr_group'))
          private$.root$build_hierarchy()

        # Post-open processing
        private$.root$post_open()
      }
    },

    #' @description Print a summary of the Zarr object to the console.
    print = function() {
      fs <- inherits(private$.store, 'zarr_localstore')
      cat('<Zarr>\n')
      cat('Version   :', private$.store$version, '\n')
      cat('Store     :', private$.store$friendlyClassName, '\n')
      if (fs)
        cat('Location  :', private$.store$root, '\n')
      if (is.null(private$.root))
        cat('Arrays    : (unitialised)\n')
      else {
        arrays <- if (inherits(private$.root, 'zarr_array')) '1 (single array store)'
                  else private$.root$count_arrays()
        cat('Arrays    :', arrays, '\n')
        if (fs)
          cat('Total size:', .size_string(sum(file.size(list.files(private$.store$root, full.names = TRUE, recursive = TRUE)))), '\n')
        private$.root$print_attributes()
      }
    },

    #' @description Print the Zarr hierarchy to the console.
    hierarchy = function() {
      cat('<Zarr hierarchy> ')
      if (is.null(private$.root))
        cat('(uninitialised)\n')
      else {
        cat(private$.store$root, '\n')
        hier <- private$.root$hierarchy_nodes(1L, 1L)
        cat(hier, sep = '')
      }
    },

    #' @description Retrieve the group or array represented by the node located
    #'   at the path.
    #' @param path The path to the node to retrieve. Must start with a
    #'   forward-slash "/".
    #' @return The [zarr_group] or [zarr_array] instance located at `path`, or
    #'   `NULL` if the `path` was not found.
    get_node = function(path) {
      if (missing(path) || !is.character(path) || !startsWith(path, '/'))
        return(NULL)

      parts <- strsplit(path, '/', fixed = TRUE)[[1L]][-1L] # Strip empty first part
      private$.root$walk_path(parts)
    },

    #' @description Add a group below a given path.
    #' @param path The path to the parent group of the new group, a single
    #'   character string.
    #' @param name The name for the new group, a single character string.
    #' @return The newly created [zarr_group], or `NULL` if the group could not
    #'   be created.
    add_group = function(path, name) {
      parent <- self$get_node(path)
      if (inherits(parent, 'zarr_group'))
        parent$add_group(name)
      else
        NULL
    },

    #' @description Add an array in a group with a given path.
    #' @param path The path to the group of the new array, a single character
    #'   string.
    #' @param name The name for the new array, a single character string.
    #' @param metadata A `list` with the metadata for the new array, or a valid
    #'   [array_builder] instance.
    #' @return The newly created [zarr_array], or `NULL` if the array could not
    #'   be created.
    add_array = function(path, name, metadata) {
      grp <- self$get_node(path)
      if (inherits(grp, 'zarr_group')) {
        grp$add_array(name, metadata)
      } else
        NULL
    },

    #' @description Delete a group from the Zarr object. This will also delete
    #'   the group from the Zarr store. The root group cannot be deleted but it
    #'   can be specified through `path = "/"` in which case the root group
    #'   loses any specific group metadata (with only the basic parameters
    #'   remaining), as well as any arrays and sub-groups if `recursive = TRUE`.
    #'   **Warning:** this operation is irreversible for many stores!
    #' @param path The path to the group.
    #' @param recursive Logical, default `FALSE`. If `FALSE`, the operation will
    #'   fail if the group has any arrays or sub-groups. If `TRUE`, the group
    #'   and all Zarr objects contained by it will be deleted.
    #' @return Self, invisible.
    delete_group = function(path, recursive = FALSE) {
      grp <- self$get_node(path)
      if (inherits(grp, 'zarr_group')) {
        if (recursive)
          grp$delete_all()
        if (inherits(grp$parent, 'zarr_group'))
          grp$parent$delete(grp$name)
      }
      invisible(self)
    },

    #' @description Delete an array from the Zarr object. If the array is the
    #'   root of the Zarr object, the Zarr object will become uninitialised.
    #'   **Warning:** this operation is irreversible for many stores!
    #' @param path The path to the array.
    #' @return Self, invisible.
    delete_array = function(path) {
      if (path == '/') {
        # Deleting a single array Zarr: result will be a group Zarr
        if (private$.store$clear())
          private$.root <- NULL
      } else {
        # Deleting an array somewhere in the hierarchy
        arr <- self$get_node(path)
        if (inherits(arr, 'zarr_array'))
          arr$parent$delete(arr$name)
      }
      invisible(self)
    }
  ),
  active = list(
    #' @field version (read-only) The version of the Zarr object.
    version = function(value) {
      if (missing(value))
        private$.store$version
    },

    #' @field root The root node of the Zarr object, usually a [zarr_group]
    #'   instance but it could also be a [zarr_array] instance. CAUTION: When
    #'   setting the root node, the entire existing hierarchy is deleted. The
    #'   hierarchy will likely be out of sync with the store after setting the
    #'   root node.
    root = function(value) {
      if (missing(value))
        private$.root
      else if (inherits(value, 'zarr_node'))
        private$.root <- value
      else
        stop('Wrong object for setting as Zarr hierarchy root node', call. = FALSE)
    },

    #' @field store (read-only) The store of the Zarr object.
    store = function(value) {
      if (missing(value))
        private$.store
    },

    #' @field domain (read-only) The `zarr_domain` instance managing the data
    #' in this `zarr` object.
    domain = function(value) {
      if (missing(value))
        private$.domain
    },

    #' @field groups (read-only) Retrieve the paths to the groups of the Zarr
    #' object, starting from the root group, as a character vector.
    groups = function(value) {
      if (missing(value)) {
        if (inherits(private$.root, 'zarr_array'))
          NULL
        else
          private$.root$groups
      }
    },

    #' @field arrays (read-only) Retrieve the paths to the arrays of the Zarr
    #'   object, starting from the root group, as a character vector.
    arrays = function(value) {
      if (missing(value)) {
        if (inherits(private$.root, 'zarr_array'))
          '/'
        else
          private$.root$arrays
      }
    }
  )
)

# --- S3 functions ---
#' Compact display of a Zarr object
#' @param object A `zarr` instance.
#' @param ... Ignored.
#' @export
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' str(africa)
str.zarr <- function(object, ...) {
  root <- object$root
  num_arrays <- if (inherits(root, 'zarr_array')) 1
                else root$count_arrays()
  plural <- if (num_arrays != 1L) 's' else ''
  cat('Zarr object with', num_arrays, paste0('array', plural))
}

#' Get a group or array from a Zarr object
#'
#' This method can be used to retrieve a group or array from the Zarr object by
#' its path.
#'
#' @param x A `zarr` object to extract a group or array from.
#' @param i The path to a group or array in `x`.
#'
#' @return An instance of `zarr_group` or `zarr_array`, or `NULL` if the path is
#'   not found.
#' @export
#'
#' @aliases [[,zarr-method
#' @docType methods
#' @examples
#' z <- create_zarr()
#' z[["/"]]
`[[.zarr` <- function(x, i) {
  x$get_node(uri_to_path(i))
}
