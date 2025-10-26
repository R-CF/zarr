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
zarr <- R6::R6Class("zarr",
  private = list(
    .store = NULL,

    .root = NULL
  ),
  public = list(
    #' @description Create a new Zarr instance. The Zarr instance manages the
    #' groups and arrays in the Zarr store that it refers to. This instance
    #' provides access to all objects in the Zarr store.
    #' @param store An instance of a [zarr_store] descendant class where the
    #'   Zarr objects are located.
    #' @returns A `zarr` object.
    initialize = function(store) {
      private$.store <- store

      # Build the node hierarchy
      metadata <- private$.store$get_metadata('')
      private$.root <- if (metadata$node_type == 'group')
        zarr_group$new(name = "", parent = NULL, store = private$.store, metadata = metadata)$build_hierarchy()
      else
        zarr_array$new(name = "", parent = NULL, store = private$.store, metadata = metadata)
    },

    #' @description Print a summary of the Zarr object to the console.
    print = function() {
      cat('<Zarr>\n')
      cat('Version   :', private$.store$version, '\n')
      cat('Store     :', private$.store$friendlyClassName, '\n')
      cat('Location  :', private$.store$root, '\n')
      arrays <- if (inherits(private$.root, 'zarr_array')) '1 (single array store)'
                else private$.root$count_arrays()
      cat('Arrays    :', arrays, '\n')
      cat('Total size:', 0, '\n')
    },

    #' @description Retrieve the group or array represented by the node located
    #'   at the path.
    #' @param path The path to the node to retrieve. Must start with a
    #'   forward-slash "/".
    #' @return The [zarr_group] or [zarr_array] instance located at `path`, or
    #'   `NULL` if the `path` was not found.
    get_node = function(path) {
      if (missing(path) || !is.character(path))
        return(NULL)

      parts <- strsplit(path, '/', fixed = TRUE)[[1L]]
      if (!(len <- length(parts)) || nzchar(parts[1L]))
        return(NULL)

      parts <- parts[-1L]
      node <- private$.root
      len <- len - 1L
      while (len > 0L && !is.null(node)) {
        node <- node$children[[parts[1L]]]
        parts <- parts[-1L]
        len <- len - 1L
      }
      node
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

    add_array = function() {

    },

    delete_group = function(path, recursive = FALSE) {

    },

    delete_array = function() {

    }
  ),
  active = list(
    #' @field version (read-only) The version of the Zarr object.
    version = function(value) {
      if (missing(value))
        private$.store$version
    },

    #' @field root (read-only) The root node of the Zarr object, usually a
    #' [zarr_group] instance but it could also be a [zarr_array] instance.
    root = function(value) {
      if (missing(value))
        private$.root
    },

    #' @field store (read-only) The store of the Zarr object.
    store = function(value) {
      if (missing(value))
        private$.store
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
`[[.zarr` <- function(x, i) {
  x$get_node(i)
}
