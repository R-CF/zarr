#' Zarr Group
#'
#' @description This class implements a Zarr group. A Zarr group is a node in
#'   the hierarchy of a Zarr object. A group is a container for other groups
#'   and arrays.
#'
#'   A Zarr group is identified by a JSON file having required metadata,
#'   specifically the attribute `"node_type": "group"`.
#' @docType class
#' @export
zarr_group <- R6::R6Class('zarr_group',
  inherit = zarr_node,
  cloneable = FALSE,
  private = list(
    # The `node` children of the current group
    .children = list()
  ),
  public = list(
    #' @description Open a group in a Zarr hierarchy. The group must already
    #'   exist in the store.
    #' @param name The name of the group. For a root group, this is the empty
    #'   string `""`.
    #' @param metadata Optional. List with the metadata of the group. If omitted
    #'   it will default to a simple Zarr v.3 group.
    #' @param parent The parent `zarr_group` instance of this new group, can be
    #'   a `zarr` instance for the root group.
    #' @param no_create_check Optional, logical flag to indicate if a check for
    #'   existence of the group in the store should be made. Default is `FALSE`.
    #'   Set to `TRUE` only when existence has been established before calling
    #'   this method.
    #' @return An instance of `zarr_group`.
    initialize = function(name, metadata = list(zarr_format = 3, node_type = "group"),
                          parent, no_create_check = FALSE) {
      if (!no_create_check) {
        # Create the group in the store if it does not yet exist
        if (inherits(parent, 'zarr')) {
          if (is.null(parent$store$get_metadata('/')))
            metadata <- parent$store$create_group(name = '')
        } else if (is.null(parent$store$get_metadata(paste0(parent$prefix, name, '/')))) {
          metadata <- parent$store$create_group(parent = parent$path, name = name)
        }
      }

      super$initialize(name, metadata, parent)
      if (metadata$node_type != 'group')
        stop('Invalid metadata for a group', call. = FALSE) # nocov

      if (inherits(parent, 'zarr_group')) parent$set_node(self)
      else parent$root <- self
    },

    #' @description This method is called automatically after a Zarr store is
    #'   opened to allow for operations after the full hierarchy has been
    #'   established. All contained children will be called similarly.
    #' @return Self, invisibly.
    post_open = function() {
      # This group first...
      # No-op for a generic group
      super$post_open()

      # ... then its children
      lapply(private$.children, function(child) child$post_open())

      invisible(self)
    },

    #' @description Print a summary of the group to the console.
    print = function() {
      name <- if (nzchar(self$name)) self$name else '[root]'
      cat('<Zarr group>', name, '\n')
      cat('Path     :', self$path, '\n')
      if (nzchar(private$.domain))
        cat('Domain   :', private$.domain, '\n')
      if (length(self$children)) {
        arrays <- sapply(self$children, inherits, "zarr_array")
        if (any(!arrays))
          cat('Sub-nodes:', paste(names(self$children)[!arrays], collapse = ', '), '\n')
        if (any(arrays))
          cat('Arrays   :', paste(names(self$children)[arrays], collapse = ', '))
      }
      private$print_details()
      self$print_attributes()
      invisible(self)
    },

    #' @description Collects the hierarchy of the group and its subgroups and
    #'   arrays in a character vector. Usually called from the Zarr object or
    #'   a group to display the full group hierarchy.
    #' @param idx,total Arguments to control indentation. Should both be 1 (the
    #'   default) when called interactively. The values will be updated during
    #'   recursion when there are groups below the current group.
    hierarchy_nodes = function(idx = 1L, total = 1L) {
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
        sg <- unlist(sapply(1L:ch, function(g) private$.children[[g]]$hierarchy_nodes(g, ch)), use.names = FALSE)
        hier <- c(hier, paste0(sep, sg))
      }
      hier
    },

    #' @description Print the Zarr hierarchy to the console from the current
    #'   group.
    hierarchy = function() {
      cat('<Zarr hierarchy>', self$path, '\n')
      hier <- self$hierarchy_nodes(1L, 1L)
      cat(hier, sep = '')
    },

    #' @description Return the hierarchy contained in the store as a tree of
    #'   group and array nodes. This method only has to be called after opening
    #'   an existing Zarr store - this is done automatically by user-facing
    #'   code. After that, users can access the `children` property of this
    #'   class.
    #' @return This [zarr_group] instance with all of its children linked.
    build_hierarchy = function() {
      prefix <- self$prefix
      dirs <- private$.store$list_dir(prefix)
      len <- length(dirs)
      if (len) {
        children <- vector("list", len)
        for (i in 1:len) {
          meta <- try(private$.store$get_metadata(paste0(prefix, dirs[i], '/')), silent = TRUE)
          if (inherits(meta, "try-error"))
            warning(paste0('Error reading metadata from location ', dirs[i], ' - ignoring'), call. = FALSE)
          else if (!is.null(meta)) {
            node <- .buildNode(name = dirs[i], metadata = meta, parent = self)
            children[[i]] <- if (inherits(node, 'zarr_node')) node else NULL
            if (meta$node_type == 'group')
              node$build_hierarchy()
          }
        }
        names(children) <- dirs
        children <- children[lengths(children) > 0L]
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

      parts <- strsplit(path, '/', fixed = TRUE)[[1L]]
      self$walk_path(parts)
    },

    #' @description Set a group or array in the current group. CAUTION: The node
    #'   must have been persisted to the store for a reliable functioning. All
    #'   that this method does is update the in-memory representation of the
    #'   Zarr hierarchy.
    #' @param node The group or array to insert in this group. CAUTION: If a
    #'   node with an identical name already exists in this group it will be
    #'   replaced by the object in this argument.
    #' @return The `node` object.
    set_node = function(node) {
      if (!inherits(node, 'zarr_node'))
        stop('Bad argument to `set_node()`', call. = FALSE)
      private$.children[[node$name]] <- node
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
    #' @return The newly created `zarr_group` instance.
    add_group = function(name) {
      zarr_group$new(name = name, parent = self)
    },

    #' @description Add an array to the Zarr hierarchy in the current group.
    #' @param name The name of the new array.
    #' @param metadata A `list` with the metadata for the new array, or an
    #'   instance of class [array_builder] whose data make a valid array
    #'   definition.
    #' @return The newly created `zarr_array` instance, or `NULL` if the array
    #'   could not be created.
    add_array = function(name, metadata) {
      if (inherits(metadata, 'array_builder'))
        metadata <- metadata$metadata()
      if (is.list(metadata)) {
        zarr_array$new(name = name, metadata = metadata, parent = self)
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
#' @examples
#' fn <- system.file("extdata", "africa.zarr", package = "zarr")
#' africa <- open_zarr(fn)
#' root <- africa[["/"]]
#' str(root)
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
#' @return An instance of `zarr_group` or `zarr_array`, or `NULL` if the path is
#'   not found.
#' @export
#' @aliases [[,zarr-group-method
#' @docType methods
#' @examples
#' z <- create_zarr()
#' tst <- z$add_group("/", "tst")
#' z$add_group("/tst", "subtst")
#' tst[["subtst"]]
`[[.zarr_group` <- function(x, i) {
  x$get_node(i)
}
