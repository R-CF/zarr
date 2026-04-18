#' Convention "uom"
#'
#' @description This class implements the "uom" convention. This convention
#'   provides a standard way of describing the unit-of-measure of Zarr array
#'   data or an attribute. In particular, the following convention is
#'   implemented here:
#'
#' ```{r schema, eval = FALSE}
#' {
#'   "schema_url": "https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json",
#'   "spec_url": "https://github.com/clbarnes/zarr-convention-uom/blob/v1/README.md",
#'   "uuid": "3bbe438d-df37-49fe-8e2b-739296d46dfb",
#'   "name": "uom",
#'   "description": "Units of measurement for Zarr arrays"
#' }
#' ```
#' @docType class
#' @export
zarr_conv_uom <- R6::R6Class('zarr_conv_uom',
  inherit = zarr_convention,
  cloneable = FALSE,
  private = list(
    # Optional: Character string with the UCUM version that the UOM is taken
    # from.
    .ucum_version = '2.2',

    # Optional: Character string with the UOM. If not given, the default is
    # unity '1'
    .ucum_unit = '1',

    # Optional: Character string with free-text description of the UOM.
    .description = character(0)
  ),
  public = list(
    #' @description Create a new instance of a "uom" convention agent.
    #' @return A new instance of a "uom" convention agent.
    initialize = function() {
      super$initialize(name   = 'uom',
                       schema = 'https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json',
                       uuid   = '3bbe438d-df37-49fe-8e2b-739296d46dfb')
      private$.spec <- 'https://github.com/clbarnes/zarr-convention-uom/blob/v1/README.md'
      private$.description <- 'Units of measurement for Zarr arrays'
    },

    #' @description Write the data of this instance in the attributes of a Zarr
    #'   object.
    #' @param attributes A `list` with Zarr attributes for a group or array. The
    #'   properties will be written to `attributes`.
    #' @return The updated attributes.
    write = function(attributes) {
      attributes$ucum <- list()
      if (nzchar(private$.ucum_version))
        attributes$ucum$version <- private$.ucum_version
      if (nzchar(private$.ucum_unit))
        attributes$ucum$unit <- private$.ucum_unit
      if (nzchar(private$.description))
        attributes$description <- private$.description
      attributes
    }
  ),
  active = list(
   #' @field version The "version" attribute under "ucum", a character string
   #' indicating the UCUM vesion that is being used.
   version = function(value) {
     if (missing(value))
       private$.ucum_version
     else if (is.character(value) && length(value) == 1L)
       private$.ucum_version <- value
     else
       stop('`version` attribute must be a character string indicating the UCUM version.', call. = FALSE)
   },

   #' @field unit The "unit" attribute under "ucum", a character string giving
   #'   the unit-of-measure in UCUM notation.
   unit = function(value) {
     if (missing(value))
       private$.ucum_unit
     else if (is.character(value) && length(value) == 1L)
       private$.ucum_unit <- value
     else
       stop('`unit` attribute must be a character string.', call. = FALSE)
   },

   #' @field description The "description" attribute, a character string giving
   #'   a free-text description of the unit-of-measure.
   description = function(value) {
     if (missing(value))
       private$.description
     else if (is.character(value) && length(value) == 1L)
       private$.description <- value
     else
       stop('`description` attribute must be a character string.', call. = FALSE)
   }
  )
)

