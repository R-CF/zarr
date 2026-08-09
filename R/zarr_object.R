#' Zarr base object
#'
#' @description This class implements the common features of objects that make
#'   up Zarr. This class is the ancestor of [zarr_node] and thus the
#'   [zarr_group] and [zarr_array] classes. This class manages common features
#'   such as names and attribute management. This class may also be used by
#'   other descendant classes that need a name and attributes (such as the
#'   coordinate system classes in package `geozarr`).
#'
#'   The main function of this class is to manage attributes of a Zarr object.
#'   Groups and arrays can have attributes, but other object descending from
#'   this class may have attributes as well. In order to accommodate the various
#'   applications, all methods dealing with attributes take a `list` object with
#'   the attributes as the first argument - the class has no private or public
#'   field to hold the attributes.
#'
#'   This class should never have to be instantiated or accessed directly.
#'   Instead, use instances of `zarr_group` or `zarr_array`. Function arguments
#'   are largely not checked, the group and array instances should do so prior
#'   to calling methods here. The big exception is checking the validity of node
#'   names.
#' @docType class
#' @export
zarr_object <- R6::R6Class('zarr_object',
  private = list(
    # The name of the object. Names have formatting rules that are applied when
    # setting this property.
    .name = NA_character_,

    # Check the proposed name of the node before setting it.
    check_name = function(name) {
      is.character(name) && length(name) == 1L && is_valid_node_name(name)
    },

    # Filter the attributes prior to printing. This is a private method that
    # descendant classes (e.g. in domains) can override to remove or add
    # attributes relevant to that class. The below base implementation does
    # nothing as attributes are not managed here. Descendant classes should NOT
    # MODIFY the attributes of the node, only return a set of attributes that
    # will be used for printing or other presentation purposes.
    display_attributes = function() {
      # Intentionally empty method
    },

    # Print one level of attributes to the console. Calls itself recursively to
    # print nested attributes. This method return a character string, which may
    # be multi-line.
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
    #' @description Initialize a new Zarr object.
    #' @param name The name of the node.
    initialize = function(name) {
      if (nzchar(name) && !private$check_name(name))
        stop('Invalid name for a Zarr object: ', name, call. = FALSE) # nocov
      private$.name <- name
    },

    #' @description Print attributes to the console. Usually called by the
    #'   [zarr_group] and [zarr_array] `print()` methods.
    #' @param dirty Optional. Logical flag that indicates if the attributes have
    #'   unsaved edits. Default is `FALSE`.
    #' @param ... Arguments passed to embedded functions. Of particular interest
    #'   is `width = .` to specify the maximum width of the columns.
    #' @return A (multi-line) character string with the attributes of the Zarr
    #'   object.
    print_attributes = function(dirty = FALSE, ...) {
      atts <- private$display_attributes()
      if (length(atts)) {
        if (dirty)
          cat('\nAttributes: (*)\n')
        else
          cat('\nAttributes:\n')
        private$print_attribute_levels(atts)
      }
    },

    #' @description Retrieve a specific attribute by path.
    #' @param atts The `list` object with the attributes.
    #' @param name The name (path) of the attribute to retrieve, using `/` as
    #'   separator for nested attributes. Numeric path segments index into array
    #'   attributes (1-based), e.g. `"zarr_conventions/2/name"` retrieves the
    #'   `name` field of the second convention object.
    #' @return The attribute value, or `NULL` if not found.
    attribute = function(atts, name) {
      if (is.null(atts) || !length(atts)) return(NULL)

      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]
      if (!length(path)) return(NULL)

      for (key in path) {
        idx <- suppressWarnings(as.integer(key))
        is_index <- !is.na(idx) && !private$is_named_list(atts)

        if (is_index) {
          if (!is.list(atts) && !is.atomic(atts)) return(NULL)
          if (idx < 1L || idx > length(atts)) return(NULL)
          atts <- atts[[idx]]
        } else {
          if (!is.list(atts)) return(NULL)
          if (is.null(atts[[key]])) return(NULL)
          atts <- atts[[key]]
        }
      }
      atts
    },

    #' @description Add an attribute to the metadata of the object. If an
    #'   attribute `name` already exists, it will be overwritten.
    #' @param atts The `list` object with the attributes.
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
    #' @return A `list` with the updated attributes.
    set_attribute = function(atts, name, value) {
      if (is.null(atts)) atts <- list()

      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]
      if (!length(path)) stop("'name' must contain at least one non-empty segment", call. = FALSE)

      private$set_nested_attribute(atts, path, value)
    },

    #' @description Append an attribute to an array in the metadata of the
    #'   object. If an attribute `name` already exists, it will be overwritten.
    #' @param atts The `list` object with the attributes.
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
    #' @return A `list` with the updated attributes.
    append_array_attribute = function(atts, name, value, after = NULL) {
      .get_nested <- function(lst, path) {
        for (key in path) {
          if (!is.list(lst) || is.null(lst[[key]])) return(NULL)
          lst <- lst[[key]]
        }
        lst
      }

      if (is.null(atts)) atts <- list()

      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]   # fix the discarded assignment

      current <- .get_nested(atts, path)
      if (is.null(current))
        new_val <- list(value)
      else if (is.list(current) && !private$is_named_list(current)) {
        idx <- if (is.null(after)) length(current) else after
        new_val <- unname(append(current, list(value), after = idx))
      } else
        stop("Attribute '", name, "' exists but is not an array; use set_attribute() to overwrite it", call. = FALSE)

      private$set_nested_attribute(atts, path, new_val)
    },

    #' @description Delete an attribute or array element. If the attribute is
    #'   not present, this method simply returns.
    #' @param atts The `list` object with the attributes.
    #' @param name Character. The name (path) of the attribute to delete, using
    #'   `/` as separator for nested attributes, e.g. `"first/second/my_att"`.
    #'   The `name` is relative to the `attributes` entry in the metadata of the
    #'   node. To target an element of a JSON array attribute, append the
    #'   1-based index as the path segment, e.g. `"first/second/my_arr/2"` to
    #'   delete the second element in the array, or
    #'   `"first/second/my_arr/2/description"` to delete only the `description`
    #'   field inside it. This nesting can be arbitrarily deep, including over
    #'   multiple JSON arrays.
    #' @return A `list` with the updated attributes.
    delete_attribute = function(atts, name) {
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

      if (is.null(atts)) return(invisible(self))

      path <- strsplit(name, "/", fixed = TRUE)[[1L]]
      path <- path[nzchar(path)]
      if (!length(path)) return(invisible(self))

      .delete_nested(atts, path)
    }
  ),
  active = list(
    #' @field name Set or retrieve the name of the Zarr object.
    name = function(value) {
      if (missing(value))
        private$.name
      else if (private$check_name(value))
        private$.name <- value
    }
  )
)
