#' Zarr object
#'
#' @description This class implements a Zarr object. A Zarr object is a set of
#'   objects that make up an instance of a Zarr data set, irrespective of where
#'   it is located. The Zarr object manages the hierarchy as well as the
#'   underlying store and any intermediate storage transformers and codecs.
#'
#'   A Zarr object may contain multiple Zarr arrays in a hierarchy. The main
#'   class for managing Zarr arrays is [zarr_array]. The hierarchy is made up of
#'   [zarr_group] instances. Each `zarr_array` is located in a `zarr_group`.
#' @docType class
zarr <- R6::R6Class("zarr",
  private = list(
    .store = NULL,

    .root = NULL,

    .version = 3L
  ),
  public = list(
    #' @description Create a new Zarr instance, with a store located on the
    #'   local file system. The root of the Zarr store will be a group to which
    #'   other groups or arrays can be added.
    #' @param location Character string that indicates a location on a file
    #'   system where the data in the Zarr object will be persisted in a Zarr
    #'   store in a directory. The character string may contain UTF-8 characters
    #'   and/or use a file URI format. The Zarr specification recommends that
    #'   the location use the ".zarr" extension to identify the location as a
    #'   Zarr store.
    #' @param version Integer indicating the version of the Zarr specification
    #'   to use. Must be 3L.
    #' @returns A `zarr` object.
    initialize = function(location, version = 3L) {
      private$.store <- zarr_localstore$new(location)
      private$.version <- version

      # Build the node hierarchy
      meta <- private$.store$get_metadata("")
      if (!is.null(meta)) {
        if (meta$node_type == 'group') {
          root_node <- zarr_group$new(name = "", store = private$.store, metadata = meta)
          private$.root <- root_node$build_hierarchy()
        }
      }
    },

    #' @description Print a summary of the Zarr object to the console.
    print = function() {
      cat('<Zarr object>\n')
      cat('Version   :', private$.version, '\n')
      cat('Store     :', private$.store$friendlyClassName, '\n')
      cat('Location  :', private$.store$root, '\n')
      cat('Arrays    :', private$.root$count_arrays(), '\n')
      cat('Total size:', 0, '\n')
    }
  ),
  active = list(
    #' @field version (read-only) The version of the Zarr object.
    version = function(value) {
      if (missing(value))
        private$.version
    },

    #' @field root (read-only) The root node of the Zarr object.
    root = function(value) {
      if (missing(value))
        private$.root
    },

    #' @field store (read-only) The store of the Zarr object.
    store = function(value) {
      if (missing(value))
        private$.store
    }
  )
)
