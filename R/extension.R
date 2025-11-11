#' Zarr extension support
#'
#' @description Many aspects of a Zarr array are implemented as extensions. More
#'   precisely, all core properties of a Zarr array except for its shape are
#'   defined as extension points, down to its data type. This class is the basic
#'   ancestor for extensions. It supports generation of the appropriate metadata
#'   for the extension, as well as processing in more specialized descendant
#'   classes.
#'
#'   Extensions can be nested. For instance, a sharding object contains one or
#'   more codecs, with both the sharding object and the codec being extension
#'   points.
#' @docType class
zarr_extension <- R6::R6Class('zarr_extension',
  cloneable = FALSE,
  private = list(
    .name = '',

    # Set the name of the extension. If changing a name after initialization is
    # not supported by the descendant class, this method should be over-written.
    # If more specialized processing is required, over-write this method as well
    # but call this method to check for syntactic validity of the name.
    set_name = function(name) {
      if (grepl('^[a-z][-a-z0-9_\\.]+$', name))
        private$.name <- name
      else
        stop('Invalid name for an extension: ', name, call. = FALSE) # nocov
    }
  ),
  public = list(
    #' @description Create a new extension object.
    #' @param name The name of the extension, a single character string.
    #' @return An instance of this class.
    initialize = function(name) {
      if (!missing(name) && is.character(name) && length(name) == 1L)
        private$set_name(name)
      else
        stop('Extension name must be a single character string.', call. = FALSE) # nocov
    },

    #' @description Return the metadata fragment that describes this extension
    #'   point object. This includes the metadata of any nested extension
    #'   objects.
    #' @return A list with the metadata of this extension point object.
    metadata_fragment = function() {
      stop('This method must be implemented by descendant classes.', call. = FALSE) # nocov
    }
  ),
  active = list(
    #' @field name The name of the extension. Setting the name may be restricted
    #'   by descendant classes.
    name = function(value) {
      if (missing(value))
        private$.name
      else if (is.character(value) && length(value) == 1L)
        private$set_name(value)
      else
        stop('Extension name must be a single character string.', call. = FALSE) # nocov
    }
  )
)
