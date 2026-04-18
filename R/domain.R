#' Zarr domain
#'
#' @description This class implements a basic domain object for Zarr stores.
#'   Domains are specific encodings for a certain domain of application. These
#'   encodings are included in the attributes of the Zarr groups and arrays and
#'   need custom code (usually in the form of another package) to interpret the
#'   attributes and properly process array data. Domains can be fully
#'   application-specific or they can implement one or more published Zarr
#'   conventions.
#'
#'   Domains have to be registered with this package to become available to the
#'   processing pipeline. Domain code is then called automatically when a Zarr
#'   store is opened for all groups and arrays in the store.
#'
#'   New domains need to inherit from this base class and implement all of the
#'   relevant methods. New domains may have additional methods specific to the
#'   domain of the data. It is generally not useful to directly instantiate this
#'   class: for a Zarr store without a registered domain an instance of this
#'   class is initialized automatically.
#' @docType class
#' @export
zarr_domain <- R6::R6Class("zarr_domain",
  cloneable = FALSE,
  private = list(
    .name = "Generic Zarr"
  ),
  public = list(
    #' @description Create a new instance of a Zarr domain. This method should
    #'   not be called directly (as in `zarr_domain$new()`); instead,
    #'   descendant classes will call this method in their initialization code.
    #' @param name Character string giving the name of the domain. This may be
    #'   any sensible string value. The name of the domain must be unique in
    #'   the session or an error will be thrown upon registering the domain.
    #' @return A new instance of a domain class.
    initialize = function(name) {
      private$.name <- name
    },

    #' @description This method will be called when the domain is requested to
    #'   asses the Zarr node for domain properties. This method must be
    #'   implemented by descendant classes and return an appropriate node if it
    #'   will manage the node. The code should be agile and return swiftly so
    #'   any non-trivial operations should be left to a later moment, for
    #'   instance when the node is accessed by the application or end-user.
    #' @param name The name of the node.
    #' @param metadata List with the metadata of the node.
    #' @param parent The parent node of this new node. May be `NULL` for a root
    #'   node.
    #' @param store The store to persist data in.
    #' @return A `zarr_node` descendant, typically an instance of a
    #'   domain-specific descendant class of `zarr_array` or `zarr_group`. If
    #'   the domain does not want to manage the node, return `FALSE`.
    build = function(name, metadata, parent, store) {
      stop("Descendant domain class must implement this method.")
    }
  ),
  active = list(
    #' @field name (read-only) The name of the domain.
    name = function(value) {
      if (missing(value))
        private$.name
    },

    #' @field can_read (read-only) Flag to indicate if this domain can read a
    #'   Zarr store using this domain. Should always be `TRUE`.
    can_read = function(value) {
      TRUE
    },

    #' @field can_write (read-only) Flag to indicate if this domain can write a
    #'   Zarr store using this domain. `TRUE` for a generic Zarr store; other
    #'   domains may report `FALSE.
    can_write = function(value) {
      TRUE
    }
  )
)
