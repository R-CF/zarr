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

    #' @description Prints the hierarchy of the group and its subgroups and
    #'   arrays to the console. Usually called from the Zarr object or its root
    #'   group to display the full group hierarchy.
    #' @param idx,total Arguments to control indentation. Should both be 1 (the
    #'   default) when called interactively. The values will be updated during
    #'   recursion when there are groups below the current group.
    hierarchy = function(idx = 1L, total = 1L) {
      if (!nzchar(private$.name)) {
        sep <- ''
        knot <- ''
      } else if (idx == total) {
        sep <- '  '
        knot <- '\u2514 '
      } else {
        sep <- '\u2502 '
        knot <- '\u251C '
      }

      nm <- private$.name
      if (!nzchar(nm))
        nm <- '/ (root group)'
      hier <- paste0(knot, '\u2630 ', nm, "\n")

      # Sub-groups
      ch <- length(private$.children)
      if (ch > 0L) {
        sg <- unlist(sapply(1L:ch, function(g) private$.children[[g]]$hierarchy(g, ch)), use.names = FALSE)
        hier <- c(hier, paste0(sep, sg))
      }
      hier
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
          meta <- private$.store$get_metadata(paste0(prefix, dirs[i], '/'))
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

    #' @description Retrieve the group or array represented by the node located
    #'   at the path relative from the current group.
    #' @param path The path to the node to retrieve. The path is relative to the
    #'   group, it must not start with a slash "/". The path may start with any
    #'   number of double dots ".." separated by slashes "/" to denote groups
    #'   higher up in the hierarchy.
    #' @return The [zarr_group] or [zarr_array] instance located at `path`, or
    #'   `NULL` if the `path` was not found.
    get_node = function(path) {
      if (missing(path) || !is.character(path) || !nzchar(path) || startsWith(path, '/'))
        return(NULL)

      matches <- regexec('^([^/]*)/(.*)', path)
      if (matches[[1L]][1L] < 0L) {
        if (path == '..')
          private$.parent
        else
          private$.children[[path]]
      } else {
        parts <- regmatches(path, matches)[[1L]]
        if (parts[2L] == '..') {
          parent <- private$.parent
          if (is.null(parent))
            NULL
          else
            parent$get_node(parts[3L])
        } else {
          node <- private$.children[[parts[2L]]]
          if (is.null(node))
            NULL
          else
            node$get_node(parts[3L])
        }
      }
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
    #' @param metadata A `list` with the metadata for the new array, or an
    #'   instance of class [array_builder] whose data make a valid array
    #'   definition.
    #' @return The newly created `zarr_array` instance, or `NULL` if the array
    #'   could not be created.
    add_array = function(name, metadata) {
      if (!private$check_name(name))
        stop('Invalid name for a Zarr object: ', name, call. = FALSE) # nocov

      if (inherits(metadata, 'array_builder'))
        metadata <- metadata$metadata()

      meta <- private$.store$create_array(self$path, name, metadata)
      if (is.list(meta)) {
        arr <- zarr_array$new(name, meta, self, self$store)
        private$.children <- append(private$.children, setNames(list(arr), name))
        arr
      } else
        NULL
    },

    #' @description Delete a group or an array contained by this group. When
    #'   deleting a group it cannot contain other groups or arrays. **Warning:**
    #'   this operation is irreversible for many stores!
    #' @param name The name of the group or array to delete. This will also
    #'   accept a path to a group or array but the group or array must be a node
    #'   directly under this group.
    #' @return Self, invisibly.
    delete = function(name) {
      name <- sub('.*/', '', name)
      ndx <- match(name, names(private$.children))
      if (!is.na(ndx) && private$.store$erase(.path2key(private$.children[[ndx]]$path)))
        private$.children <- private$.children[-ndx]
      invisible(self)
    },

    #' @description Delete all the groups and arrays contained by this group,
    #'   including any sub-groups and arrays. Any specific metadata attached to
    #'   this group is deleted as well - only a basic metadata document is
    #'   maintained. **Warning:** this operation is irreversible for many
    #'   stores!
    #' @return Self, invisibly.
    delete_all = function() {
      prefix <- self$prefix
      if (private$.store$erase_prefix(prefix)) {
        private$.children <- list()
        private$.metadata <- private$.store$get_metadata(prefix)
      }
      invisible(self)
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

#' Get a group or array from a Zarr group
#'
#' This method can be used to retrieve a group or array from the Zarr group by
#' a relative path to the desired group or array.
#'
#' @param x A `zarr_group` object to extract a group or array from.
#' @param i The path to a group or array in `x`. The path is relative to the
#'   group, it must not start with a slash "/". The path may start with any
#'   number of double dots ".." separated by slashes "/" to denote groups
#'   higher up in the hierarchy.
#'
#' @return An instance of `zarr_group` or `zarr_array`, or `NULL` if the path is
#'   not found.
#' @export
#'
#' @aliases [[,zarr-group-method
#' @docType methods
#' @examples
#' z <- create_zarr()
#' z$add_group("/", "tst")
#' z$add_group("/tst", "subtst")
#' tst <- z[["/tst"]]
#' tst[["subtst"]]
`[[.zarr_group` <- function(x, i) {
  x$get_node(i)
}
