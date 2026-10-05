# Tests for Zarr data types that map to bit64::integer64 in R: int64 (native)
# and uint32 (which does not fit in an R integer).
#
# The test values deliberately include magnitudes that a double cannot hold
# exactly (> 2^53), so that any silent detour through double precision shows
# up as a wrong value rather than passing by accident.

skip_if_not_installed("bit64")

i64 <- function(x) bit64::as.integer64(x)

# Representable int64 extremes plus values around the int32 and 2^53 limits.
# INT64_MIN is NA_integer64_ in bit64 and INT64_MAX is the default fill value,
# so the usable range is one short at each end.
int64_values <- i64(c("-9223372036854775807", "-9007199254740993", "-2147483649",
                      "-1", "0", "1", "2147483648", "9007199254740993",
                      "9223372036854775806"))

# The bytes codec returns chunk-shaped data; as.vector() would also strip the
# integer64 class, so drop the dim attribute instead.
flat <- function(x) { dim(x) <- NULL; x }

new_int64_array <- function(z, name, shape, chunk_shape, data_type = "int64") {
  def <- define_array(data_type, shape)
  def$chunk_shape <- chunk_shape
  z$add_array("/", name, def)
}

# ==== Data type ===============================================================

test_that("int64 data type maps to integer64 with INT64_MAX fill value", {
  dt <- zarr_data_type$new("int64")
  expect_equal(dt$Rtype, "integer64")
  expect_equal(dt$size, 8L)
  expect_identical(dt$fill_value, i64("9223372036854775807"))
})

test_that("uint32 data type maps to integer64 with UINT32_MAX fill value", {
  dt <- zarr_data_type$new("uint32")
  expect_equal(dt$Rtype, "integer64")
  expect_equal(dt$size, 4L)
  expect_identical(dt$fill_value, i64("4294967295"))
})

# ==== Bytes codec =============================================================

test_that("bytes codec round-trips int64 values, little endian", {
  dt <- zarr_data_type$new("int64")
  codec <- zarr_codec_bytes$new(dt, length(int64_values), list(endian = "little"))
  raw <- codec$encode(int64_values)
  expect_length(raw, 8L * length(int64_values))
  expect_identical(flat(codec$decode(raw)), int64_values)
})

test_that("bytes codec round-trips int64 values, big endian", {
  dt <- zarr_data_type$new("int64")
  codec <- zarr_codec_bytes$new(dt, length(int64_values), list(endian = "big"))
  expect_identical(flat(codec$decode(codec$encode(int64_values))), int64_values)
})

test_that("bytes codec writes int64 in two's complement", {
  dt <- zarr_data_type$new("int64")
  codec <- zarr_codec_bytes$new(dt, 2L, list(endian = "little"))
  raw <- codec$encode(i64(c("-1", "2147483648")))
  expect_identical(raw[1:8], as.raw(rep(0xff, 8)))
  expect_identical(raw[9:16], as.raw(c(0, 0, 0, 0x80, 0, 0, 0, 0)))
})

test_that("bytes codec round-trips uint32 values in 4 bytes each", {
  vals <- i64(c("0", "1", "2147483647", "2147483648", "4294967294"))
  dt <- zarr_data_type$new("uint32")
  codec <- zarr_codec_bytes$new(dt, length(vals), list(endian = "little"))
  raw <- codec$encode(vals)
  expect_length(raw, 4L * length(vals))
  expect_identical(raw[13:16], as.raw(c(0, 0, 0, 0x80)))  # 2^31, not a negative int32
  expect_identical(flat(codec$decode(raw)), vals)
})

# ==== Writing and reading through an array ====================================

test_that("int64 matrix round-trips through a memory store", {
  x <- int64_values[c(1:9, 9:1)]
  dim(x) <- c(6L, 3L)
  arr <- new_int64_array(create_zarr(), "a", c(6L, 3L), c(4L, 2L))
  arr$write(x)
  expect_identical(arr$read(), x)
})

test_that("int64 matrix round-trips through a local store", {
  x <- int64_values[c(1:9, 9:1)]
  dim(x) <- c(6L, 3L)
  arr <- new_int64_array(create_zarr(tempfile(fileext = ".zarr")), "a", c(6L, 3L), c(4L, 2L))
  arr$write(x)
  expect_identical(arr$read(), x)
})

test_that("int64 vector round-trips, single chunk and multiple chunks", {
  arr <- new_int64_array(create_zarr(), "one", length(int64_values), length(int64_values))
  arr$write(int64_values)
  expect_identical(arr$read(), int64_values)

  arr <- new_int64_array(create_zarr(), "many", length(int64_values), 2L)
  arr$write(int64_values)
  expect_identical(arr$read(), int64_values)
})

test_that("int64 selection read spanning several chunks", {
  x <- int64_values[c(1:9, 9:1)]
  dim(x) <- c(6L, 3L)
  arr <- new_int64_array(create_zarr(), "a", c(6L, 3L), c(4L, 2L))
  arr$write(x)
  expect_identical(arr$read(list(c(3L, 5L), c(2L, 3L))), x[3:5, 2:3])
  expect_identical(arr[3:5, 2:3], x[3:5, 2:3])
})

test_that("int64 partial write leaves other data intact", {
  x <- int64_values[c(1:9, 9:1)]
  dim(x) <- c(6L, 3L)
  arr <- new_int64_array(create_zarr(), "a", c(6L, 3L), c(4L, 2L))
  arr$write(x)

  patch <- i64(c("-9223372036854775807", "9223372036854775806", "42", "-42"))
  dim(patch) <- c(2L, 2L)
  arr$write(patch, selection = list(c(4L, 5L), c(2L, 3L)))
  x[4:5, 2:3] <- patch
  expect_identical(arr$read(), x)
})

test_that("int64 scalar array round-trips", {
  def <- define_array("int64", integer(0))
  arr <- create_zarr()$add_array("/", "s", def)
  arr$write(i64("9007199254740993"))
  expect_identical(flat(arr$read()), i64("9007199254740993"))
})

test_that("uint32 values above the int32 range round-trip", {
  x <- i64(c("0", "2147483647", "2147483648", "4294967294"))
  arr <- new_int64_array(create_zarr(), "u", 4L, 2L, data_type = "uint32")
  arr$write(x)
  expect_identical(arr$read(), x)
})

# ==== Fill value and NA =======================================================

test_that("unwritten int64 chunks read as NA", {
  arr <- new_int64_array(create_zarr(), "a", c(4L, 4L), c(2L, 2L))
  expect_true(all(is.na(arr$read())))
})

test_that("int64 NA is written as fill value and read back as NA", {
  x <- i64(c("1", NA, "9007199254740993", NA))
  arr <- new_int64_array(create_zarr(), "a", 4L, 2L)
  arr$write(x)
  expect_identical(arr$read(), x)

  arr$raw_read <- TRUE
  expect_identical(arr$read(), i64(c("1", "9223372036854775807", "9007199254740993", "9223372036854775807")))
})

test_that("int64 values equal to a custom fill value read as NA", {
  def <- define_array("int64", 3L)
  def$fill_value <- -1
  arr <- create_zarr()$add_array("/", "a", def)
  arr$write(i64(c("-1", "0", "9007199254740993")))
  expect_identical(arr$read(), i64(c(NA, "0", "9007199254740993")))
})

test_that("int64 default fill value survives re-opening the store", {
  fn <- tempfile(fileext = ".zarr")
  new_int64_array(create_zarr(fn), "a", 4L, 2L)
  z <- open_zarr(fn)
  expect_identical(z[["/a"]]$data_type$fill_value, i64("9223372036854775807"))
})

test_that("int64 data survives re-opening the store", {
  fn <- tempfile(fileext = ".zarr")
  new_int64_array(create_zarr(fn), "a", length(int64_values), 4L)$write(int64_values)
  z <- open_zarr(fn)
  expect_identical(z[["/a"]]$read(), int64_values)
})

# ==== Interoperability ========================================================
# Stores written byte by byte here, without the package's codecs, in the layout
# zarr-python produces: C order, no compressor.

write_raw_int64 <- function(fn, x, endian) {
  con <- file(fn, "wb")
  on.exit(close(con))
  writeBin(unclass(x), con, size = 8L, endian = endian)
}

test_that("int64 array in a Zarr v3 store from another implementation", {
  fn <- tempfile(fileext = ".zarr")
  dir.create(file.path(fn, "c", "0"), recursive = TRUE)
  writeLines('{"zarr_format": 3, "node_type": "array", "shape": [2, 3],
    "data_type": "int64", "fill_value": 0,
    "chunk_grid": {"name": "regular", "configuration": {"chunk_shape": [2, 3]}},
    "chunk_key_encoding": {"name": "default", "configuration": {"separator": "/"}},
    "codecs": [{"name": "bytes", "configuration": {"endian": "little"}}]}',
    file.path(fn, "zarr.json"))
  # Row-major on disk: rows (1, 2, 3) and (4, 5, 9007199254740993)
  vals <- i64(c("1", "2", "3", "4", "5", "9007199254740993"))
  write_raw_int64(file.path(fn, "c", "0", "0"), vals, "little")

  expected <- vals
  dim(expected) <- c(3L, 2L)
  expected <- t(expected)
  expect_identical(open_zarr(fn)$root$read(), expected)
})

test_that("big-endian int64 array in a Zarr v2 store", {
  fn <- tempfile(fileext = ".zarr")
  dir.create(fn)
  writeLines('{"zarr_format": 2, "shape": [4], "chunks": [4], "dtype": ">i8",
    "compressor": null, "fill_value": 0, "filters": null, "order": "C"}',
    file.path(fn, ".zarray"))
  vals <- i64(c("-9007199254740993", "-1", "2147483648", "9007199254740993"))
  write_raw_int64(file.path(fn, "0"), vals, "big")
  expect_identical(open_zarr(fn)$root$read(), vals)
})
