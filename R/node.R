#' Zarr Hierarchy node
#'
#' @description This class implements a Zarr node. The node is an element in the
#'   hierarchy of the Zarr object. As per the Zarr specification, the node is
#'   either a group or an array. Thus, this class is the ancestor of the
#'   [zarr_group] and [zarr_array] classes. This class manages common features
#'   such as names, key, prefixes and paths, as well as the hierarchy between
#'   nodes and the [zarr_store] for persistent storage.
#'
#'   This class should never have to be instantiated or accessed directly.
#'   Instead, use instances of `zarr_group` or `zarr_array`. Function arguments
#'   are largely not checked, the group and array instances should do so prior
#'   to calling methods here. The big exception is checking the validity of node
#'   names.
#' @docType class
zarr_node <- R6::R6Class('zarr_node',
  cloneable = FALSE,
  private = list(
    # The name of the node. Names have formatting rules that are applied when
    # setting this property.
    .name = '',

    # The parent `node` of this node. This value is `NULL` for the root node.
    .parent = NULL,

    # The store where this node and all of its contents are persisted.
    .store = NULL,

    # The metadata document of this node, a `list`. Flag if it has been edited.
    .metadata = list(),
    .meta_dirty = FALSE,

    # Name of the domain managing the node, if any. The name is set by the node
    # in the domain.
    .domain = '',

    # Check the proposed name of the node before setting it.
    check_name = function(name) {
      is.character(name) && length(name) == 1L && .is_valid_node_name(name)
    },

    # Print one level of attributes to the console. Calls itself recursively to
    # print nested attributes.
    print_attribute_levels = function(atts, indent = 0L) {
      pad   <- strrep("  ", indent)
      width <- max(nchar(names(atts)))

      for (nm in names(atts)) {
        val <- atts[[nm]]

        if (is.list(val) && !is.null(names(val)) && any(nzchar(names(val)))) {
          # Named list: JSON object, recurse
          cat(pad, formatC(nm, width = width, flag = "-"), ":\n", sep = "")
          private$print_attribute_levels(val, indent + 1L)
        } else if (is.list(val) && any(vapply(val, is.list, logical(1L)))) {
          # Unnamed list containing lists: JSON array of objects, recurse each element
          cat(pad, formatC(nm, width = width, flag = "-"), ":\n", sep = "")
          for (i in seq_along(val)) {
            cat(pad, "  [", i, "]\n", sep = "")
            elem <- val[[i]]
            if (is.list(elem) && !is.null(names(elem)) && any(nzchar(names(elem))))
              private$print_attribute_levels(elem, indent + 2L)
            else
              cat(pad, "    ", elem, "\n", sep = "")
          }
        } else if (is.list(val)) {
          # Unnamed list of scalars: flat JSON array
          cat(pad, formatC(nm, width = width, flag = "-"), ": [",
              paste(unlist(val), collapse = ", "), "]\n", sep = "")
        } else if (length(val) > 1L) {
          cat(pad, formatC(nm, width = width, flag = "-"), ": [",
              paste(val, collapse = ", "), "]\n", sep = "")
        } else {
          cat(pad, formatC(nm, width = width, flag = "-"), ": ", val, "\n", sep = "")
        }
      }
    },

    # Print domain-specific details, if any. A domain can print any details for
    # a group or an array. Details are printed after the Zarr object details and
    # before the attributes. If printing details, implementations should start
    # with an empty line to create visual separation between sections. This
    # implementation on the base class prints nothing.
    print_details = function() {
      # Intentionally empty method
    },

    # Filter the attributes prior to printing. This is a private method that
    # descendant classes (e.g. in domains) can override to remove or add
    # attributes relevant to that class. The below base implementation simply
    # returns all attributes. Descendant classes should NOT MODIFY the
    # attributes of the node, only return a set of attributes that will be used
    # for printing or other presentation purposes.
    display_attributes = function() {
      private$.metadata[['attributes']]
    },

    # Set a value at a nested path within a list, creating missing nodes
    set_nested_attribute = function(lst, path, value) {
      key <- path[[1L]]
      idx <- suppressWarnings(as.integer(key))
      is_index <- !is.na(idx) && !private$is_named_list(lst)

      if (is_index) {
        if (idx < 1L || idx > length(lst) + 1L)
          stop("Index ", idx, " is out of range for array of length ",
               length(lst), call. = FALSE)
        if (length(path) == 1L) {
          lst[[idx]] <- value
        } else {
          child <- if (idx <= length(lst) && is.list(lst[[idx]])) lst[[idx]] else list()
          lst[[idx]] <- private$set_nested_attribute(child, path[-1L], value)
        }
      } else {
        if (length(path) == 1L) {
          lst[[key]] <- value
        } else {
          existing <- lst[[key]]
          child <- if (is.list(existing)) existing
          else if (is.atomic(existing) && length(existing) > 1L) as.list(existing)
          else list()
          lst[[key]] <- private$set_nested_attribute(child, path[-1L], value)
        }
      }
      lst
    },

    # Heuristic: a named list is a JSON object {}; unnamed is a JSON array []
    is_named_list = function(x) {
      is.list(x) && !is.null(names(x)) && any(nzchar(names(x)))
    }
  ),
  public = list(
    #' @description Initialize a new node in a Zarr hierarchy.
    #' @param name The name of the node.
    #' @param metadata List with the metadata of the node.
    #' @param parent The parent node of this new node. Must be omitted when
    #' initializing a root node.
    #' @param store The store to persist data in. Ignored if `parent` is
    #'   specified.
    initialize = function(name, metadata, parent, store) {
      if (missing(parent) || is.null(parent))
        private$.name <- ''
      else if (private$check_name(name))
        private$.name <- name
      else
        stop('Invalid name for a Zarr object: ', name, call. = FALSE) # nocov

      private$.metadata <- metadata
      if (!missing(parent))
        private$.parent <- parent
      private$.store <- if (is.null(private$.parent)) store else parent$store
    },

    #' @description This method is called automatically after a Zarr store is
    #'   opened to allow for operations after the full hierarchy has been
    #'   established. This is a no-op here, descendant classes with specific
    #'   requirements should implement this method.
    #' @return Self, invisibly.
    post_open = function() {
      invisible(self)
    },

    #' @description Print the metadata "attributes" to the console. Usually
    #' called by the [zarr_group] and [zarr_array] `print()` methods.
    #' @param ... Arguments passed to embedded functions. Of particular interest
    #' is `width = .` to specify the maximum width of the columns.
    print_attributes = function(...) {
      atts <- private$display_attributes()
      if (length(atts)) {
        if (private$.meta_dirty)
          cat('\nAttributes: (*)\n')
        else
          cat('\nAttributes:\n')
        private$print_attribute_levels(atts)
      }
    },

    #' @description Retrieve the relative path from the current node to the
    #'   indicated node or path. In the relative path parent nodes are indicated
    #'   with `..`, child nodes start with the child node name down to the
    #'   target node.
    #' @param to Either a `zarr_node` instance or a character string giving the
    #'   object to which the relative path reference is sought.
    #' @return A character string with the relative path from this node. If the
    #'   `to` argument is empty or points to this node '.' is returned. Note
    #'   that the relative path has no leading slash (as regular Zarr paths do).
    relative_path = function(to) {
      if (inherits(to, 'zarr_node')) to <- to$path
      to_parts <- strsplit(to, '/', fixed = TRUE)[[1L]][-1L]
      if (!length(to_parts)) return('.')
      if (any(to_parts %in% c('.', '..')))
        stop('Invalid `to` path: segments must be valid names', call. = FALSE)

      from_parts <- strsplit(self$path, '/', fixed = TRUE)[[1L]][-1L]

      n <- min(length(from_parts), length(to_parts))
      common <- 0L
      while (common < n && from_parts[common + 1L] == to_parts[common + 1L]) {
        common <- common + 1L
      }

      parts <- c(rep('..', length(from_parts) - common),
                 to_parts[seq_len(length(to_parts) - common) + common])
      if (!length(parts)) '.' else paste(parts, collapse = '/')
    },

    #' @description Retrieve a specific attribute by path.
    #' @param name The name (path) of the attribute to retrieve, using `/` as
    #'   separator for nested attributes. Numeric path segments index into array
    #'   attributes (1-based), e.g. `"zarr_conventions/2/name"` retrieves the
    #'   `name` field of the second convention object.
    #' @return The attribute value, or `NULL` if not found.
    attribute = function(name) {
      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]
      if (!length(path)) return(NULL)

      lst <- private$.metadata[["attributes"]]
      if (is.null(lst)) return(NULL)

      for (key in path) {
        idx <- suppressWarnings(as.integer(key))
        is_index <- !is.na(idx) && !private$is_named_list(lst)

        if (is_index) {
          if (!is.list(lst) && !is.atomic(lst)) return(NULL)
          if (idx < 1L || idx > length(lst)) return(NULL)
          lst <- lst[[idx]]
        } else {
          if (!is.list(lst)) return(NULL)
          if (is.null(lst[[key]])) return(NULL)
          lst <- lst[[key]]
        }
      }
      lst
    },

    #' @description Add an attribute to the metadata of the object. If an
    #'   attribute `name` already exists, it will be overwritten.
    #' @param name The name of the attribute. The name may be a compound path,
    #'   relative to the "attributes" entry in the metadata, using a slash "/"
    #'   as path separator. Each of the elements in the path (between slashes)
    #'   must begin with a letter and be composed of letters, digits, and
    #'   underscores and can be at most 255 characters long. Missing path
    #'   elements will be created.
    #' @param value The value of the attribute. This can be of any supported
    #'   type, including a vector or list of values. In general, an attribute
    #'   should be a character value, a numeric value, a logical value, or a
    #'   short vector or list of any of these.
    #' @return Self, invisibly.
    set_attribute = function(name, value) {
      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]
      if (!length(path)) stop("'name' must contain at least one non-empty segment", call. = FALSE)

      atts <- private$.metadata[["attributes"]]
      if (is.null(atts)) atts <- list()

      result <- private$set_nested_attribute(atts, path, value)
      private$.metadata[["attributes"]] <- result
      private$.meta_dirty <- TRUE
      invisible(self)
    },

    #' @description Append an attribute to an array in the metadata of the
    #'   object. If an attribute `name` already exists, it will be overwritten.
    #' @param name The name of the attribute. The name may be a compound path,
    #'   relative to the "attributes" entry in the metadata, using a slash "/"
    #'   as path separator. Each of the elements in the path (between slashes)
    #'   must begin with a letter and be composed of letters, digits, and
    #'   underscores and can be at most 255 characters long. Missing path
    #'   elements will be created.
    #' @param value The value of the attribute. This can be of any supported
    #'   type, including a vector or list of values. In general, an attribute
    #'   should be a character value, a numeric value, a logical value, or a
    #'   short vector or list of any of these.
    #' @param after A subscript, after which `value` is to be appended. The
    #'   default is `NULL`, meaning that `value` will be placed after the
    #'   existing values. Specifying `after = 0L` will place `value` before the
    #'   existing values.
    #' @return Self, invisibly.
    append_array_attribute = function(name, value, after = NULL) {
      .get_nested <- function(lst, path) {
        for (key in path) {
          if (!is.list(lst) || is.null(lst[[key]])) return(NULL)
          lst <- lst[[key]]
        }
        lst
      }

      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]   # fix the discarded assignment

      atts <- private$.metadata[["attributes"]]
      if (is.null(atts)) atts <- list()

      current <- .get_nested(atts, path)
      if (is.null(current))
        new_val <- list(value)
      else if (is.list(current) && !private$is_named_list(current)) {
        idx <- if (is.null(after)) length(current) else after
        new_val <- unname(append(current, list(value), after = idx))
      } else
        stop("Attribute '", name, "' exists but is not an array; use set_attribute() to overwrite it", call. = FALSE)

      private$.metadata[["attributes"]] <- private$set_nested_attribute(atts, path, new_val)
      private$.meta_dirty <- TRUE
      invisible(self)
    },

    #' @description Delete an attribute or array element. If the attribute is
    #'   not present, this method simply returns.
    #' @param name Character. The name (path) of the attribute to delete, using
    #'   `/` as separator for nested attributes, e.g. `"first/second/my_att"`.
    #'   The `name` is relative to the `attributes` entry in the metadata of the
    #'   node. To target an element of a JSON array attribute, append the
    #'   1-based index as the path segment, e.g. `"first/second/my_arr/2"` to
    #'   delete the second element in the array, or
    #'   `"first/second/my_arr/2/description"` to delete only the `description`
    #'   field inside it. This nesting can be arbitrarily deep, including over
    #'   multiple JSON arrays.
    #' @return Self, invisibly.
    delete_attribute = function(name) {
      .delete_nested <- function(lst, path) {
        key <- path[[1L]]

        # Numeric segment — index into an unnamed array
        idx <- suppressWarnings(as.integer(key))
        is_index <- !is.na(idx) && !private$is_named_list(lst)

        if (is_index) {
          if (idx < 1L || idx > length(lst))
            return(lst)  # out of range — silently ignore
          if (length(path) == 1L) {
            # Delete the array element itself
            lst[[idx]] <- NULL
          } else {
            # Recurse into the array element
            child <- lst[[idx]]
            if (!is.list(child)) return(lst)
            lst[[idx]] <- .delete_nested(child, path[-1L])
          }
        } else {
          if (!is.list(lst) || is.null(lst[[key]]))
            return(lst)  # absent — silently ignore
          if (length(path) == 1L) {
            # Delete the named key
            lst[[key]] <- NULL
          } else {
            # Recurse into the named child
            child <- lst[[key]]
            if (!is.list(child)) return(lst)
            lst[[key]] <- .delete_nested(child, path[-1L])
          }
        }
        lst
      }

      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]
      if (!length(path)) return(invisible(self))

      atts <- private$.metadata[["attributes"]]
      if (is.null(atts)) return(invisible(self))

      atts <- .delete_nested(atts, path)

      if (length(atts))
        private$.metadata[["attributes"]] <- atts
      else
        private$.metadata["attributes"] <- NULL

      private$.meta_dirty <- TRUE
      invisible(self)
    },

    #' @description Persist any edits to the group or array to the store.
    save = function() {
      if (private$.meta_dirty) {
        private$.store$set_metadata(self$prefix, private$.metadata)
        private$.meta_dirty <- FALSE
      }
    }
  ),
  active = list(
    #' @field name (read-only) The name of the node.
    name = function(value) {
      if (missing(value))
        private$.name
    },

    #' @field parent The parent of the node. For a root node this returns
    #'   `NULL`, otherwise this `zarr_group` or `zarr_array` instance. CAUTION:
    #'   Setting the parent of a node can invalidate the Zarr hierarchy -
    #'   expert use only.
    parent = function(value) {
      if (missing(value))
        private$.parent
      else if (is.null(value) || inherits(value, 'zarr_node'))
        private$.parent <- value
    },

    #' @field store (read-only) The store of the node.
    store = function(value) {
      if (missing(value))
        private$.store
    },

    #' @field path (read-only) The path of this node, relative to the root node
    #'   of the hierarchy.
    path = function(value) {
      if (missing(value)) {
        if (nzchar(private$.name)) {
          pp <- private$.parent$path
          if (pp == '/') paste0('/', private$.name)
          else paste(pp, private$.name, sep = '/')
        } else '/'
      }
    },

    #' @field prefix (read-only) The prefix of this node, relative to the root
    #'   node of the hierarchy.
    prefix = function(value) {
      if (missing(value)) {
        if (nzchar(private$.name)) {
          pp <- private$.parent$prefix
          paste0(pp, private$.name, '/')
        } else ''
      }
    },

    #' @field metadata The metadata document of this node, a `list`. CAUTION:
    #'   Setting a list that is not properly describing this object will render
    #'   the object invalid.
    metadata = function(value) {
      if (missing(value))
        private$.metadata
      else {
        private$.metadata <- value
        private$.meta_dirty <- TRUE
      }
    },

    #' @field attributes (read-only) Retrieve the list of attributes of this
    #'   object. Attributes can be added or modified with the `set_attribute()`
    #'   method or removed with the `delete_attributes()` method.
    attributes = function(value) {
      if (missing(value))
        private$.metadata[['attributes']]
    }
  )
)
