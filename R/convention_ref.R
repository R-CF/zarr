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

    # Mandatory: Path to a Zarr group or array in the current Zarr store
    # (relative path) or the store in the external `.uri` reference (absolute
    # path.
    .node = character(0),

    # Optional: JSON pointer to a referenced attribute in the metadata of
    # `node`.
    .attribute = character(0)
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
      if (!nzchar(private$.node))
        stop('`node` field must be set.', call. = FALSE)

      if (nzchar(private$.uri))
        attributes$uri <- private$.uri
      attributes$node <- private$.node
      if (nzchar(private$.attribute))
        attributes$attribute <- private$.attribute
      attributes
    },

    #' @description Validate and parse a JSON Pointer (RFC 6901) into its
    #'   reference tokens.
    #' @param ptr The character string from the "attribute" field to parse.
    #' @return Character vector of raw tokens, or throws an error.
    parse_json_pointer = function(ptr) {
      if (!is.character(ptr) || length(ptr) != 1L)
        stop('`ptr` must be a single character string.', call. = FALSE)

      # Empty string = valid pointer to the root document; no tokens
      if (ptr == '') return(character(0L))

      if (!startsWith(ptr, '/'))
        stop('Invalid JSON Pointer: must be empty or start with "/".', call. = FALSE)

      tokens <- strsplit(ptr, '/', fixed = TRUE)[[1L]][-1L]
      invalid <- grepl('~(?![01])', tokens, perl = TRUE)
      if (any(invalid))
        stop('Invalid reference token(s): ', paste(tokens[invalid], collapse = ', '), call. = FALSE)

      tokens <- gsub('~1', '/', tokens, fixed = TRUE)
      tokens <- gsub('~0', '~', tokens, fixed = TRUE)
      tokens
    }
  ),
  active = list(
   #' @field uri The "uri" field, a character string of an external Zarr
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
       stop('`uri` field must be a character string representing a URI.', call. = FALSE)
   },

   #' @field node The "node" field, a character string giving the path to
   #'   a group or array in the current Zarr store or in the  store pointed at by the "uri"
   #'   field.
   node = function(value) {
     if (missing(value))
       private$.node
     else if (is.character(value) && length(value) == 1L)
       private$.node <- value
     else
       stop('`node` field must be a character string.', call. = FALSE)
   },

   #' @field attribute The "attribute" field, a character string with a JSON
   #'   pointer to a referenced attribute in the metadata of the referenced
   #'   `node`.
   attribute = function(value) {
     if (missing(value))
       private$.attribute
     else if (self$parse_json_pointer(value))
       private$.attribute <- value
     else
       stop('`attribute` field must be a character string with a valid JSON pointer.', call. = FALSE)
   }
  )
)
