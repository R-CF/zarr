# Shared fixtures for the print tests, plain text and cli.

# A small hierarchy: /, /grp, /grp/sub, arrays /a (2-D) and /grp/b (scalar).
make_tree <- function(location) {
  z <- if (missing(location)) create_zarr() else create_zarr(location)
  z$add_group("/", "grp")
  z$add_group("/grp", "sub")
  def <- define_array("float64", c(4L, 6L))
  def$chunk_shape <- c(2L, 3L)
  a <- z$add_array("/", "a", def)
  a$write(matrix(as.numeric(1:24), 4L, 6L))
  z$add_array("/grp", "b", define_array("int32", integer(0)))
  z
}

# Capture cli output as a character vector, one element per line.
cli_out <- function(expr) cli::cli_fmt(expr)

# Number of leading characters before `pattern` on the first line matching it.
indent_of <- function(lines, pattern) {
  line <- grep(pattern, lines, value = TRUE, fixed = TRUE)[1L]
  as.integer(regexpr(pattern, line, fixed = TRUE)) - 1L
}
