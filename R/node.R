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

    # Check the proposed name of the node before setting it.
    check_name = function(name) {
      is.character(name) && length(name) == 1L && .is_valid_node_name(name)
    }
  ),
  public = list(
    #' @description Initialize a new node in a Zarr hierarchy.
    #' @param name The name of the node.
    #' @param metadata List with the metadata of the node.
    #' @param parent The parent node of this new node. May be omitted when
    #' initializing a root node.
    #' @param store The store to persist data in. Ignored if a `parent` is
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

    #' @description Print the metadata "attributes" to the console. Usually
    #' called by the [zarr_group] and [zarr_array] `print()` methods.
    #' @param ... Arguments passed to embedded functions. Of particular interest
    #' is `width = .` to specify the maximum width of the columns.
    print_attributes = function(...) {
      df <- .slim.data.frame(private$.metadata[['attributes']], ...)
      if (nrow(df)) {
        if (private$.meta_dirty)
          cat('Attributes: (*)\n')
        else
          cat('Attributes:\n')
        print(df, right = FALSE, row.names = FALSE)
      }
    },

    #' @description Add an attribute to the metadata of the object. If an
    #'   attribute `name` already exists, it will be overwritten.
    #' @param name The name of the attribute. The name must begin with a letter
    #'   and be composed of letters, digits, and underscores, with a maximum
    #'   length of 255 characters.
    #' @param value The value of the attribute. This can be of any supported
    #'   type, including a vector or list of values. In general, an attribute
    #'   should be a character value, a numeric value, a logical value, or a
    #'   short vector or list of any of these.
    #' @return Self, invisibly.
    set_attribute = function(name, value) {
      atts <- private$.metadata[['attributes']]
      if (is.null(atts)) {
        atts <- setNames(list(value), name)
      } else {
        atts[name] <- list(value)
      }
      private$.metadata[['attributes']] <- atts
      private$.meta_dirty <- TRUE
      invisible(self)
    },

    #' @description Delete attributes. If an attribute in `name` is not present
    #' this method simply returns.
    #' @param name Vector of names of the attributes to delete.
    #' @return Self, invisibly.
    delete_attributes = function(name) {
      atts <- private$.metadata[['attributes']]
      if (!is.null(atts)) {
        atts[name] <- NULL
        if (length(atts))
          private$.metadata[['attributes']] <- atts
        else
          private$.metadata['attributes'] <- NULL
      }
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

    #' @field parent (read-only) The parent of the node. For a root node this
    #' returns `NULL`, otherwise this `zarr_group` or `zarr_array` instance.
    parent = function(value) {
      if (missing(value))
        private$.parent
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

    #' @field metadata (read-only) The metadata document of this node, a list.
    metadata = function(value) {
      if (missing(value))
        private$.metadata
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
