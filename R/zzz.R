#nocov start
# Create environment for the package
Zarr.options <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  # User-modifiable options
  assign("chunk_length", 100L, envir = Zarr.options)
}
#nocov end
