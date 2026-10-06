# Tests for the element order of stored chunks: the transpose codec plus the
# C-order serialisation of the array->bytes codec, applied as one permutation.

# Array definition with a single chunk, no compression, and the given
# transpose order (`NULL` removes the transpose codec: portable C order).
order_def <- function(data_type, shape, order = "default") {
  def <- define_array(data_type, shape)
  def$chunk_shape <- shape
  def$remove_codec("blosc")
  if (is.null(order)) def$portable <- TRUE
  else if (!identical(order, "default")) {
    def$remove_codec("transpose")
    def$add_codec("transpose", list(order = as.integer(order)), .position = 1L)
  }
  def
}

# Write `x` to a new local store, return the store location.
write_ordered <- function(x, data_type, order = "default") {
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_array("/", "a", order_def(data_type, dim(x) %||% length(x), order))$write(x)
  fn
}

raw_chunk <- function(fn, n, what = "integer", size = 4L) {
  key <- list.files(file.path(fn, "a"), pattern = "^c", full.names = TRUE)
  readBin(key, what, n, size = size, endian = "little")
}

# ==== .chunk_permutation() ====================================================

test_that(".chunk_permutation() for default, C and custom orders", {
  expect_null(.chunk_permutation(list(zarr_codec_transpose$new(3L)), 3L))
  expect_equal(.chunk_permutation(list(), 3L), 3:1)
  expect_equal(.chunk_permutation(list(zarr_codec_transpose$new(3L, list(order = c(1L, 2L, 0L)))), 3L), c(1L, 3L, 2L))
  expect_null(.chunk_permutation(list(), 1L))
  expect_null(.chunk_permutation(list(), 0L))
})

# ==== Bytes on disk ===========================================================

test_that("default order stores chunks in R order", {
  x <- matrix(1:6, 2L, 3L)
  expect_equal(raw_chunk(write_ordered(x, "int32"), 6L), 1:6)
})

test_that("portable arrays store chunks in C order", {
  x <- matrix(1:6, 2L, 3L)
  fn <- write_ordered(x, "int32", NULL)
  expect_equal(raw_chunk(fn, 6L), c(1L, 3L, 5L, 2L, 4L, 6L))
  expect_equal(open_zarr(fn)[["/a"]]$read(), x)
})

test_that("every transpose order of a 3-D array stores the Zarr-defined bytes and round-trips", {
  x <- array(1:24, 2:4)
  perms <- list(c(0, 1, 2), c(0, 2, 1), c(1, 0, 2), c(1, 2, 0), c(2, 0, 1), c(2, 1, 0))
  for (ord in perms) {
    fn <- write_ordered(x, "int32", ord)
    # Zarr: transposed array T = aperm(x, order + 1), serialised in C order
    expect_equal(raw_chunk(fn, 24L), as.vector(aperm(aperm(x, ord + 1L), 3:1)),
                 info = paste(ord, collapse = ","))
    expect_equal(open_zarr(fn)[["/a"]]$read(), x, info = paste(ord, collapse = ","))
  }
})

# ==== Round trips through partial chunks ======================================

test_that("partial writes and reads with a custom order span chunks correctly", {
  x <- array(as.numeric(1:120), c(4L, 5L, 6L))
  def <- order_def("float64", dim(x), c(2, 0, 1))
  def$chunk_shape <- c(3L, 2L, 4L)
  fn <- tempfile(fileext = ".zarr")
  arr <- create_zarr(fn)$add_array("/", "a", def)
  arr$write(x[1:2, , ], selection = list(c(1L, 2L), c(1L, 5L), c(1L, 6L)))
  arr$write(x[3:4, , ], selection = list(c(3L, 4L), c(1L, 5L), c(1L, 6L)))
  arr2 <- open_zarr(fn)[["/a"]]
  expect_equal(arr2$read(), x)
  expect_equal(arr2[2:3, 2:4, 3:5], x[2:3, 2:4, 3:5])
})

test_that("portable 1-D and scalar arrays round-trip", {
  fn <- write_ordered(1:5, "int32", NULL)
  expect_equal(raw_chunk(fn, 5L), 1:5)
  expect_equal(open_zarr(fn)[["/a"]]$read(), 1:5)

  def <- define_array("int32", integer(0))
  def$portable <- TRUE
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_array("/", "s", def)$write(42L)
  expect_equal(as.vector(open_zarr(fn)[["/s"]]$read()), 42L)
})

# ==== Data types that need care when permuted =================================

test_that("integer64 survives permutation", {
  skip_if_not_installed("bit64")
  x <- bit64::as.integer64(c("-9007199254740993", "1", "2", "9007199254740993", "5", "6"))
  dim(x) <- c(2L, 3L)
  for (ord in list(NULL, c(0, 1))) {
    fn <- write_ordered(x, "int64", ord)
    expect_identical(open_zarr(fn)[["/a"]]$read(), x)
  }
  expect_identical(raw_chunk(write_ordered(x, "int64", NULL), 6L, "double", 8L),
                   unclass(x[c(1, 3, 5, 2, 4, 6)]))
})

test_that("uint32 survives permutation", {
  skip_if_not_installed("bit64")
  x <- bit64::as.integer64(c("0", "2147483648", "4294967294", "1", "7", "8"))
  dim(x) <- c(2L, 3L)
  expect_identical(open_zarr(write_ordered(x, "uint32", NULL))[["/a"]]$read(), x)
})

test_that("portable string arrays round-trip", {
  x <- matrix(c("a", "bb", "µs", "東京", "e", "ff"), 2L, 3L)
  fn <- tempfile(fileext = ".zarr")
  def <- define_array("string", c(2L, 3L))
  def$portable <- TRUE
  create_zarr(fn)$add_array("/", "s", def)$write(x)
  expect_equal(open_zarr(fn)[["/s"]]$read(), x)
})
