#nocov start
# Create environments for domains and package options
Zarr.domains <- new.env(parent = emptyenv())
Zarr.options <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  # User-modifiable options
  .default_options()

  # Load user options from file
  f <- file.path(tools::R_user_dir("zarr", "config"), "options.rds")
  if (file.exists(f)) {
    saved <- tryCatch(readRDS(f), error = function(e) list())
    saved <- saved[intersect(names(saved), ls(Zarr.options))]
    nms <- names(saved)
    lapply(seq_along(saved), function(i) zarr_options(nms[i], saved[[i]]))
  }

  # Register the generic conventions for Zarr
  assign("conventions", data.frame(
    name   = c('ref', 'uom'),
    schema = c('https://raw.githubusercontent.com/R-CF/zarr_convention_ref/refs/tags/v2.0.0/schema.json',
               'https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json'),
    uuid   = c('d89b30cf-ed8c-43d5-9a16-b492f0cd8786',
               '3bbe438d-df37-49fe-8e2b-739296d46dfb')
  ), envir = Zarr.options)
}
#nocov end

.default_options <- function() {
  # Modifiable options
  assign('chunk_length', 100L, envir = Zarr.options) # Maximum dimension chunk length for auto chunking
  assign('min_compress', 100L, envir = Zarr.options) # Minimum array size before compression is set
  assign('eps', .Machine$double.eps^0.5, envir = Zarr.options)
  assign('parallel_threshold', 20, envir = Zarr.options)
  assign('chunk_cache_bytes', 64L * 1024L * 1024L, envir = Zarr.options)  # 64 MB default, per array
  assign('group_style', c('blue', 'bold'), envir = Zarr.options)
  assign('array_style', c('green', 'bold'), envir = Zarr.options)
  assign('label_style', c('black', 'bold'), envir = Zarr.options)
  assign('text_style', 'blue', envir = Zarr.options)
  assign('minor_style', 'grey', envir = Zarr.options)

  # Internal options
  if (requireNamespace('cli', quietly = TRUE))
    assign('zarr_theme', .make_zarr_theme(), envir = Zarr.options)
}

#' Save the options to a file in the user config directory
#'
#' This functions saves the options of the `zarr` package in a RDS file in the
#' config directory of the user. This will persist modified options over multiple
#' sessions. The file is automatically read when a new session starts. Note that
#' saving the options is only necessary when any options have been modified and
#' these changes need to apply to future sessions as well.
#' @return Nothing.
#' @export
#' @examples
#' save_options()
save_options <- function() {
  f <- file.path(tools::R_user_dir("zarr", "config"), "options.rds")
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  saveRDS(as.list(Zarr.options), f)
  invisible(NULL)
}

#' Reset all options to their default value
#'
#' This functions resets the options of the `zarr` package to their default
#' value.
#' @return Nothing.
#' @export
#' @examples
#' reset_options()
reset_options <- function() {
  unlink(dirname(file.path(tools::R_user_dir("zarr", "config"), "options.rds")), recursive = TRUE)
  .default_options()
  invisible(NULL)
}
