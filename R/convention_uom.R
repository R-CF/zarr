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
zarr_convention_uom <- R6::R6Class('zarr_convention_uom',
  inherit = zarr_convention,
  cloneable = FALSE,
  private = list(
    # Optional: Character string with the UCUM version that the UOM is taken from
    .ucum_version = '2.2',

    # Optional: Character string with the UOM. If not given, the default is unity '1'
    .ucum_unit = '1',

    # Optional: Character string with free-text description of the UOM
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

    #' @description Set the attributes for this convention for use in a Zarr
    #'   node.
    #' @param unit Character string. The "unit" attribute under "ucum", giving
    #'   the unit-of-measure in UCUM notation.
    #' @param version Optional, character string. The "version" attribute under
    #'   "ucum", indicating the UCUM version that is being used.
    #' @param description Optional, a character string with the "description"
    #'   attribute, giving a free-text description of the unit-of-measure.
    set = function(unit, version, description) {
      if (is.character(unit) && length(unit) == 1L && nzchar(unit))
        private$.ucum_unit <- unit
      else
        stop('Attribute `unit` must be a character string', call. = FALSE)

      if (is.character(version) && length(version) == 1L && nzchar(version))
        private$.ucum_version <- version
      else
        stop('Attribute `version` must be a character string indicating the UCUM version', call. = FALSE)

      if (!missing(description) && is.character(description) && length(description) == 1L && nzchar(description))
        private$.description <- description
      else
        stop('Attribute `description` must be a character string', call. = FALSE)
    },

    #' @description Reset any attributes that may have been set to their default
    #'   values. Only the properties of the convention itself will remain in
    #'   place.
    clear = function() {
      private$.ucum_unit <- '1'
      private$.ucum_version <- '2.2'
      private$.description <- character(0)
    },

    #' @description Return the data of this instance for inclusion in the
    #'   attributes of a Zarr object.
    #' @return A `list` with Zarr attributes for a group or array.
    as_list = function() {
      ucum <- list(version = private$.ucum_version, unit = private$.ucum_unit)
      if (nzchar(private$.description))
        list(ucum = ucum, description = private$.description)
      else
        list(ucum = ucum)
    }
  )
)

