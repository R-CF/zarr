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
    .attribute = character(0),

    # Validate and parse a JSON Pointer (RFC 6901) into its reference tokens.
    # @param ptr The character string from the "attribute" field to parse.
    # @return Character vector of raw tokens, or throws an error.
    parse_json_pointer = function(ptr) {
      if (!is.character(ptr) || length(ptr) != 1L)
        stop('`ptr` must be a single character string', call. = FALSE)

      # Empty string = valid pointer to the root document; no tokens
      if (ptr == '') return(character(0L))

      if (!startsWith(ptr, '/'))
        stop('Invalid JSON Pointer: must be empty or start with "/"', call. = FALSE)

      tokens <- strsplit(ptr, '/', fixed = TRUE)[[1L]][-1L]
      invalid <- grepl('~(?![01])', tokens, perl = TRUE)
      if (any(invalid))
        stop('Invalid reference token(s): ', paste(tokens[invalid], collapse = ', '), call. = FALSE)

      tokens <- gsub('~1', '/', tokens, fixed = TRUE)
      tokens <- gsub('~0', '~', tokens, fixed = TRUE)
      tokens
    }

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

    #' @description Set the attributes for this convention for use in a Zarr
    #'   node.
    #' @param node Character string. Path to the Zarr node containing the data
    #'   of interest. The path is relative to the referring node when argument
    #'   `uri` is missing, absolute from the root of the Zarr store otherwise.
    #' @param uri Optional, character string. URI of an external Zarr store.
    #'   Omit for nodes that are in the same local store as the referring node.
    #' @param attribute Optional, a character string with a JSON pointer to a
    #'   referenced attribute in the metadata of the referenced `node`.
    set = function(node, uri, attribute) {
      if (is.character(node) && length(node) == 1L && nzchar(node))
        private$.node <- node
      else
        stop('Argument `node` must be a character string', call. = FALSE)

      if (!missing(uri) && is.character(uri) && length(uri) == 1L && nzchar(uri)) # FIXME: Must test for URI formatting
        private$.uri <- uri
      else
        stop('Argument `uri` must be a character string representing a URI', call. = FALSE)

      if (!missing(attribute) && private$parse_json_pointer(attribute))
        private$.attribute <- attribute
      else
        stop('`attribute` field must be a character string with a valid JSON pointer', call. = FALSE)
    },

    #' @description Clear any attributes that may have been set. Only the
    #' properties of the convention itself will remain in place.
    clear = function() {
      private$.node <- character(0)
      private$.attribute <- character(0)
      private$.uri <- character(0)
    },

    #' @description Return the data of this instance for inclusion in the
    #'   attributes of a Zarr object.
    #' @return A `list` with Zarr attributes for a group or array.
    as_list = function() {
      if (!nzchar(private$.node))
        stop('`node` field must be set.', call. = FALSE)

      out <- if (nzchar(private$.uri)) list(uri = private$.uri) else list()
      out$node <- c(out, list(node = private$.node))
      if (nzchar(private$.attribute))
        out$attribute <- c(out, list(attribute = private$.attribute))
      out
    }
  )
)
