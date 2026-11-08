#' Deprecated functions in package zarr
#'
#' @description These functions are provided for compatibility with older
#'   versions of `zarr` only, and will be removed in a future release.
#'
#'   * `auto_chunk()`: use [optimal_chunking()] instead. `auto_chunk()` limits
#'     the chunk length along each dimension separately, which does not
#'     control the size of a chunk. [optimal_chunking()] targets a number of
#'     values per chunk. Deprecated November 2026, defunct May 2027, removed
#'     November 2027.
#'
#' @param dims Integer vector with the lengths along every dimension of the
#'   array.
#' @param max_chunk Optional. Integer giving the maximum length of a chunk
#'   along each dimension. Defaults to `zarr_options("chunk_length")`.
#' @return `auto_chunk()`: an integer vector with the same length as argument
#'   `dims` giving the length of a chunk along each dimension of the array.
#' @name zarr-deprecated
#' @keywords internal
NULL
