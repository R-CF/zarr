#' Zarr convention
#'
#' @description This class implements a basic Zarr convention. A convention is a
#'   set of attributes specific to a certain domain of application. These
#'   attributes are included in Zarr group and array attributes and are
#'   interpreted by application code. Conventions may be grouped in domains and
#'   combined with other conventions.
#'
#'   Application-specific conventions need to inherit from this base class and
#'   redefine relevant methods. Descendant conventions may have additional
#'   methods specific to the domain of the data.
#'
#'   It is not useful to directly instantiate this class, use a descendant
#'   convention instead. It is recommended that descendant classes use the
#'   "zarr_conv_****" naming pattern and that they are included in a R package
#'   with similar conventions and/or domain(s).
#' @docType class
#' @export
zarr_convention <- R6::R6Class('zarr_convention',
  cloneable = FALSE,
  private = list (
    .name        = '',   # The name of the convention, may have a trailing :
    .schema      = '',   # The URL to the schema of the convention
    .spec        = '',   # The URL to the specification of the convention
    .uuid        = '',   # The UUID (in character format) of the convention
    .description = ''    # Short description of the convention
  ),
  public = list(
    #' @description Create a new instance of a Zarr convention agent. This is
    #' a "virtual" ancestor class that should not be instantiated directly -
    #' instead use one of the descendant classes.
    #' @param name String value with the name of the convention.
    #' @param schema String value with the URL to the schema of the convention.
    #' @param uuid String value with the UUID of the convention.
    #' @return A new instance of a Zarr convention agent.
    initialize = function(name, schema, uuid) {
      private$.name <- name
      private$.schema <- schema
      private$.uuid <- uuid
    },

    #' @description Register the use of a convention in the attributes of a Zarr
    #'   object.
    #' @param attributes A `list` with Zarr attributes for a group or array.
    #' @param brief Logical flag to indicate if the registration should only
    #'   include the name and the schema URL or all details (default).
    #' @return The updated attributes.
    register = function(attributes, brief = FALSE) {
      conv <- attributes$zarr_conventions %||% list()
      conv <- if (brief)
        append(conv, list(schema_url = private$.schema, name = private$.name))
      else
        append(conv, list(schema_url  = private$.schema,
                          spec_url    = private$.spec,
                          uuid        = private$.uuid,
                          name        = private$.name,
                          description = private$.description))
      attributes$zarr_conventions <- list(conv)
      attributes
    },

    #' @description Write the data of a convention instance in the attributes of
    #'   a Zarr object. This method does not do any actual writing. Descendant
    #'   classes should implement their specific solutions.
    #' @param attributes A `list` with Zarr attributes for a group or array. The
    #'   properties will be written at the root level of `attributes`.
    #' @return The updated attributes.
    write = function(attributes) {
      attributes
    }
  ),
  active = list(
    #' @field name (read-only) The name of the convention, possibly with a
    #'   trailing semi-colon ":".
    name = function(value) {
      if (missing(value))
        private$.name
    },

    #' @field schema (read-only) The URL to the schema of the convention.
    schema = function(value) {
      if (missing(value))
        private$.schema
    },

    #' @field uuid (read-only) The UUID of the convention, in string format.
    uuid = function(value) {
      if (missing(value))
        private$.uuid
    },

    #' @field spec The URL to the specification of the convention.
    spec = function(value) {
      if (missing(value))
        private$.spec
      else
        private$.spec <- value
    },

    #' @field description A short description of the convention.
    description = function(value) {
      if (missing(value))
        private$.description
      else
        private$.description <- value
    }
  )
)
