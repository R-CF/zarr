#' Create a Zarr store
#'
#' This function creates a Zarr instance, with a store located on the local file
#' system. The root of the Zarr store will be a group to which other groups or
#' arrays can be added.
#' @param location Character string that indicates a location on a file system
#'   where the data in the Zarr object will be persisted in a Zarr store in a
#'   directory. The character string may contain UTF-8 characters and/or use a
#'   file URI format. The Zarr specification recommends that the location use
#'   the ".zarr" extension to identify the location as a Zarr store.
#' @param version Integer indicating the version of the Zarr specification to
#'   use. Must be 3.
#' @return A [zarr] object.
#' @export
#' @examples
#' fn <- tempfile(fileext = ".zarr")
#' my_zarr_object <- zarr_create(fn)
#' my_zarr_object$store$root
#' unlink(fn)
zarr_create <- function(location, version = 3L) {
  if (version != 3L)
    stop('Only supported Zarr version is 3.', call. = FALSE) # nocov

  zarr$new(location, version)
}
