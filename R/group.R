#' Zarr Group
#'
#' @description This class implements a Zarr group. A Zarr group is a node in
#'   the hierarchy of a Zarr data set. A group is a container for other groups
#'   and arrays.
#'
#'   A Zarr group is identified by a JSON file having required metadata,
#'   specifically the attribute '"node_type": "group"'.
#' @docType class
zarr_group <- R6::R6Class('zarr_group',
  inherit = zarr_node,
  cloneable = FALSE,
  private = list(
    # The `node` children of the current group
    .children = list()
  ),
  public = list(
    #' @description Initialize a new group in a Zarr hierarchy. The group must
    #'   already exist in the store
    #' @param name The name of the group. For a root group, this is the empty
    #'   string `""`.
    #' @param metadata List with the metadata of the group.
    #' @param parent The parent `zarr_group` instance of this new group, can be
    #'   missing or `NULL` for the root group.
    #' @param store The [zarr_store] instance to persist data in.
    #' @return An instance of `zarr_group`.
    initialize = function(name, metadata, parent, store) {
      super$initialize(name, metadata, parent, store)
      if (metadata$node_type != 'group')
        stop('Invalid metadata for a group.', call. = FALSE) # nocov
    },

    #' @description Print a summary of the group to the console.
    print = function() {
      name <- if (nzchar(self$name)) self$name else '[root]'
      cat('<Zarr group>', name, '\n')
      cat('Path     :', self$path, '\n')
      if (length(self$children)) {
        arrays <- sapply(self$children, inherits, "zarr_array")
        if (any(!arrays))
          cat('Sub-nodes:', paste(names(self$children)[!arrays], collapse = ', '), '\n')
        if (any(arrays))
          cat('Arrays   :', paste(names(self$children)[arrays], collapse = ', '))
      }
      invisible(self)
    },

    #' @description Return the hierarchy contained in the store as a tree of
    #'   group and array nodes. This method only has to be called after opening
    #'   an existing Zarr store - this is done automatically by user-facing
    #'   code. After that, users can access the `children` property of this
    #'   class.
    #' @return This [zarr_group] instance with all of its children linked.
    build_hierarchy = function() {
      # FIXME: Make lapply once final and well-tested
      prefix <- self$prefix
      dirs <- private$.store$list_dir(prefix)
      len <- length(dirs)
      if (len) {
        children <- vector("list", len)
        for (i in 1:len) {
          meta <- private$.store$get_metadata(paste0(prefix, dirs[i]))
          if (!is.null(meta)) {
            if (meta$node_type == 'group') {
              grp <- zarr_group$new(dirs[i], meta, self, self$store)
              grp$build_hierarchy()
              children[[i]] <- grp
            } else if (meta$node_type == 'array')
              children[[i]] <- zarr_array$new(dirs[i], meta, self, self$store)
          }
        }
        # FIXME: There could be empty entries in children (although there shouldn't be)
        names(children) <- dirs
        private$.children <- children
      }
      invisible(self)
    },

    #' @description Count the number of arrays in this group, optionally
    #' including arrays in sub-groups.
    #' @param recursive Logical flag that indicates if arrays in sub-groups
    #' should be included in the count. Default is `TRUE`.
    count_arrays = function(recursive = TRUE) {
      if (length(private$.children)) {
        if (recursive)
          sum(sapply(private$.children, function(c) {
            if (inherits(c, 'zarr_array')) 1L else c$count_arrays(TRUE)
          }))
        else
          sum(sapply(private$.children, inherits, 'zarr_array'))
      } else 0L
    },

    #' @description Add a group to the Zarr hierarchy under the current group.
    #' @param name The name of the new group.
    #' @return The newly created `zarr_group` instance, or `NULL` if the group
    #'   could not be created.
    add_group = function(name) {
      if (!private$check_name(name))
        stop('Invalid name for a Zarr object: ', name, call. = FALSE) # nocov

      meta <- private$.store$create_group(self$path, name)
      if (is.list(meta)) {
        grp <- zarr_group$new(name, meta, self, self$store)
        private$.children <- append(private$.children, setNames(list(grp), name))
        grp
      } else
        NULL
    },

    #' @description Add an array to the Zarr hierarchy in the current group.
    #' @param name The name of the new array.
    #' @param metadata A `list` with the metadata for the new array.
    #' @return The newly created `zarr_array` instance, or `NULL` if the array
    #'   could not be created.
    add_array = function(name, metadata) {
      if (!private$check_name(name))
        stop('Invalid name for a Zarr object: ', name, call. = FALSE) # nocov

      meta <- private$.store$create_array(self$path, name, metadata)
      if (is.list(meta)) {
        arr <- zarr_array$new(name, meta, self, self$store)
        private$.children <- append(private$.children, setNames(list(arr), name))
        arr
      } else
        NULL
    }
  ),
  active = list(
    #' @field children (read-only) The children of the group. This is a list of
    #' `zarr_group` and `zarr_array` instances, or the empty list if the group
    #' has no children.
    children = function(value) {
      if (missing(value))
        private$.children
    },

    #' @field groups (read-only) Retrieve the paths to the sub-groups of the
    #' hierarchy starting from the current group, as a character vector.
    groups = function(value) {
      if (missing(value)) {
        chld <- lapply(private$.children, function(c) {if (inherits(c, 'zarr_group')) c$groups})
        out <- c(self$path, unlist(chld[lengths(chld) > 0L]))
        names(out) <- NULL
        out
      }
    },

    #' @field arrays (read-only) Retrieve the paths to the arrays of the
    #' hierarchy starting from the current group, as a character vector.
    arrays = function(value) {
      if (missing(value)) {
        out <- lapply(private$.children, function(c) {if (inherits(c, 'zarr_group')) c$arrays else c$path})
        out <- unlist(out[lengths(out) > 0L])
        names(out) <- NULL
        out
      }
    }
  )
)

# --- S3 functions ---
#' Compact display of a Zarr group
#' @param object A `zarr_group` instance.
#' @param ... Ignored.
#' @export
str.zarr_group <- function(object, ...) {
  len <- length(children <- object$children)
  if (len) {
    num_arrays <- sum(sapply(children, inherits, 'zarr_array'))
    arrays <- if (num_arrays == 1L) '1 array' else paste(num_arrays, 'arrays')
    num_groups <- len - num_arrays
    groups <- if (num_groups == 1L) '1 sub-group' else paste(num_groups, 'sub-groups')
    cat('Zarr group with', arrays, 'and', groups)
  } else
    cat('Zarr group without arrays or sub-groups')

}
