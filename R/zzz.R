#nocov start
# Create environments for domains and package options
Zarr.domains <- new.env(parent = emptyenv())
Zarr.options <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  # User-modifiable options
  assign("chunk_length", 100L, envir = Zarr.options)
  assign("eps", .Machine$double.eps^0.5, envir = Zarr.options)

  # Register the generic conventions for Zarr
  assign("conventions", data.frame(
    name   = c('ref', 'uom'),
    schema = c('https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/schema.json',
               'https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json'),
    uuid   = c('d89b30cf-ed8c-43d5-9a16-b492f0cd8786',
               '3bbe438d-df37-49fe-8e2b-739296d46dfb')
  ), envir = Zarr.options)
}
#nocov end
