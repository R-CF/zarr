#' Convention "ref"
#'
#' @description This class implements the "ref" convention. This convention
#'   provides a standard way of referring to objects from a referring group or
#'   array in a Zarr store. The referenced object may be located in the same
#'   Zarr store or in an external Zarr store. In particular, the following
#'   convention is implemented here:
#'
#' ```{r schema, eval = FALSE}
#' {
#'  "schema_url": "https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/schema.json",
#'  "spec_url": "https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/README.md",
#'  "uuid": "d89b30cf-ed8c-43d5-9a16-b492f0cd8786",
#'  "name": "ref",
#'  "description": "Referencing Zarr objects external to the current Zarr object"
#' }
#' ```
#' @docType class
#' @export
zarr_conv_ref <- R6::R6Class('zarr_conv_ref',
  inherit = zarr_convention,
  cloneable = FALSE,
  private = list(
    # Optional: URI, preferably locatable, to an external Zarr store containing
    # the referenced object.
    .uri = character(0),

    # Optional: Path to a Zarr array in the current Zarr store or the store in
    # the external `.uri` reference.
    .array = character(0),

    # Optional: Path to a Zarr array in the current Zarr store or the store in
    # the external `.uri` reference.
    .group = character(0),

    # Optional: Fully-qualified path from the root of the metadata file to a
    # referenced attribute.
    .attribute = character(0),

    # Optional: 0-based index into the array, if `.attribute` points at an
    # array.
    .index = numeric(0),

    # Optional: If `.attribute` points at an array of sub-schemas, the
    # sub-schema whose "name" property has this value.
    .name = 'pixel'
  ),
  public = list(
    #' @description Create a new instance of a "ref" convention agent.
    #' @return A new instance of a "ref" convention agent.
    initialize = function() {
      super$initialize(name   = 'ref',
                       schema = 'https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/schema.json',
                       uuid   = 'd89b30cf-ed8c-43d5-9a16-b492f0cd8786')
      private$.spec <- 'https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/README.md'
      private$.description <- 'Referencing Zarr objects external to the current Zarr object'
    },

    #' @description Write the data of this instance in the attributes of a Zarr
    #'   object.
    #' @param attributes A `list` with Zarr attributes for a group or array. The
    #'   properties will be written to `attributes`.
    #' @return The updated attributes.
    write = function(attributes) {
      if (nzchar(private$.array) == nzchar(private$.group))
        stop('Either of `array` or `group` must be set.', call. = FALSE)
      if (length(private$.index) && nzchar(private$.name))
        stop('Only one of `index` or `name` may be set.', call. = FALSE)

      if (nzchar(private$.uri))
        attributes$uri <- private$.uri
      if (nzchar(private$.array))
        attributes$array <- private$.array
      else
        attributes$group <- private$.group
      if (nzchar(private$.attribute)) {
        attributes$attribute <- private$.attribute
        if (length(private$.index))
          attributes$index <- private$.index
        else if (nzchar(private$.name))
          attributes$name <- private$.name
      }
      attributes
    }
  ),
  active = list(
   #' @field uri The "uri" attribute, a character string of an external Zarr
   #'   store. The URI must follow RFC 3986 and preferably points to a locatable
   #'   resource like a file on a file system or a store on a web site that is
   #'   accessible to the same process that opened up the Zarr store having this
   #'   reference.
   uri = function(value) {
     if (missing(value))
       private$.uri
     else if (is.character(value) && length(value) == 1L) # FIXME: Must test for URI formatting
       private$.uri <- value
     else
       stop('`uri` attribute must be a character string representing a URI.', call. = FALSE)
   },

   #' @field array The "array" attribute, a character string giving the path to
   #'   an array in the current Zarr store or a store pointed at by the "uri"
   #'   attribute.
   array = function(value) {
     if (missing(value))
       private$.array
     else if (is.character(value) && length(value) == 1L)
       private$.array <- value
     else
       stop('`array` attribute must be a character string.', call. = FALSE)
   },

   #' @field group The "group" attribute, a character string giving the path to
   #'   a group in the current Zarr store or a store pointed at by the "uri"
   #'   attribute.
   group = function(value) {
     if (missing(value))
       private$.group
     else if (is.character(value) && length(value) == 1L)
       private$.group <- value
     else
       stop('`group` attribute must be a character string.', call. = FALSE)
   },

   #' @field attribute The "attribute" attribute, a character string with a
   #'   fully-qualified path from the root of the metadata file to a referenced
   #'   attribute.
   attribute = function(value) {
     if (missing(value))
       private$.attribute
     else if (is.numeric(value) && length(value) == 1L)
       private$.attribute <- value
     else
       stop('`attribute` attribute must be a character string.', call. = FALSE)
   },

   #' @field index If the `attribute` attribute points at an array, the 0-based
   #'   index into the array.
   index = function(value) {
     if (missing(value))
       private$.index
     else if (is.integer(value) && length(value) == 1L)
       private$.index <- value
     else
       stop('`index` attribute must be a single integer value.', call. = FALSE)
   },

   #'@field name A character string. If the `attribute` attribute points at an
   #'  array of sub-schemas, the sub-schema whose "name" property has this
   #'  value.
   name = function(value) {
     if (missing(value))
       private$.name
     else if (is.character(value) && length(value) == 1L)
       private$.name <- value
     else
       stop('`name` attribute must be a character string.', call. = FALSE)
   }
  )
)

