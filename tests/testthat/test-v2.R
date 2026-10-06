# Tests for reading Zarr v2 stores. The stores are written byte by byte here,
# without the package's codecs, in the layout that zarr-python produces.

# Write a JSON document to `path` inside store `root`.
write_json_doc <- function(root, path, txt) {
  fn <- file.path(root, path)
  dir.create(dirname(fn), recursive = TRUE, showWarnings = FALSE)
  writeLines(txt, fn)
}

# Write a raw chunk of numeric data to `path` inside store `root`.
write_chunk <- function(root, path, x, size, endian = "little") {
  fn <- file.path(root, path)
  dir.create(dirname(fn), recursive = TRUE, showWarnings = FALSE)
  con <- file(fn, "wb")
  on.exit(close(con))
  writeBin(x, con, size = size, endian = endian)
}

zarray <- function(dtype, shape, chunks, order = "C", fill = "0", extra = "") {
  sprintf('{"zarr_format": 2, "shape": [%s], "chunks": [%s], "dtype": "%s",
    "compressor": null, "fill_value": %s, "filters": null, "order": "%s"%s}',
    paste(shape, collapse = ", "), paste(chunks, collapse = ", "), dtype, fill, order, extra)
}

# A v2 store with a root group, a sub-group and arrays with attributes.
make_v2_hierarchy <- function() {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zgroup", '{"zarr_format": 2}')
  write_json_doc(root, ".zattrs", '{"title": "v2 test store", "version": 1}')
  write_json_doc(root, "grp/.zgroup", '{"zarr_format": 2}')
  write_json_doc(root, "grp/.zattrs", '{"description": "a sub-group"}')

  # 2 x 3 float64 array in C order, one chunk
  write_json_doc(root, "grp/temp/.zarray", zarray("<f8", c(2, 3), c(2, 3)))
  write_json_doc(root, "grp/temp/.zattrs", '{"units": "K"}')
  write_chunk(root, "grp/temp/0.0", c(1.5, 2.5, 3.5, 4.5, 5.5, 6.5), 8L)
  root
}

# ==== Hierarchy and attributes ================================================

test_that("v2 store opens with its group hierarchy", {
  z <- open_zarr(make_v2_hierarchy())
  expect_equal(z$version, 2L)
  expect_true(inherits(z[["/grp"]], "zarr_group"))
  expect_true(inherits(z[["/grp/temp"]], "zarr_array"))
})

test_that("v2 attributes are read from .zattrs", {
  z <- open_zarr(make_v2_hierarchy())
  expect_equal(z$root$attributes$title, "v2 test store")
  expect_equal(z[["/grp"]]$attributes$description, "a sub-group")
  expect_equal(z[["/grp/temp"]]$attributes$units, "K")
})

test_that("v2 C-order float64 array reads in R order", {
  z <- open_zarr(make_v2_hierarchy())
  expect_equal(z[["/grp/temp"]]$read(), matrix(c(1.5, 2.5, 3.5, 4.5, 5.5, 6.5), 2, 3, byrow = TRUE))
})

# ==== Data types ==============================================================

v2_single_array <- function(dtype, values, size, endian = "little", fill = "0", shape = length(values)) {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zarray", zarray(dtype, shape, shape, fill = fill))
  write_chunk(root, "0", values, size, endian)
  open_zarr(root)$root
}

test_that("v2 float32 array", {
  arr <- v2_single_array("<f4", c(0.5, -1.25, 1e10), 4L)
  expect_equal(arr$data_type$data_type, "float32")
  expect_equal(arr$read(), c(0.5, -1.25, 1e10))
})

test_that("v2 int16 big-endian array", {
  arr <- v2_single_array(">i2", c(-300L, 0L, 300L), 2L, endian = "big", fill = "99")
  expect_equal(arr$data_type$data_type, "int16")
  expect_equal(arr$read(), c(-300L, 0L, 300L))
})

test_that("v2 uint8 array", {
  arr <- v2_single_array("|u1", c(0L, 128L, 255L), 1L, fill = "1")
  expect_equal(arr$data_type$data_type, "uint8")
  expect_equal(arr$read(), c(0L, 128L, 255L))
})

test_that("v2 bool array", {
  arr <- v2_single_array("|b1", c(1L, 0L, 1L), 1L, fill = "false")
  expect_equal(arr$data_type$data_type, "bool")
  expect_equal(arr$read(), c(TRUE, FALSE, TRUE))
})

test_that("v2 NaN fill value maps to NA", {
  arr <- v2_single_array("<f8", c(1, NaN, 3), 8L, fill = '"NaN"')
  expect_true(is.nan(arr$data_type$fill_value))
  expect_equal(arr$read(), c(1, NA, 3))
})

test_that("v2 fixed-width unicode strings", {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zarray", zarray("<U3", 2, 2, fill = '""'))
  # UCS-4: each character is a 4-byte little-endian code point, padded with 0
  cp <- c(utf8ToInt("ab"), 0L, utf8ToInt("µs!"))
  write_chunk(root, "0", cp, 4L)
  arr <- open_zarr(root)$root
  expect_equal(arr$data_type$data_type, "string")
  expect_equal(arr$read(), c("ab", "µs!"))
})

# ==== Layout ==================================================================

test_that("v2 F-order array needs no permutation", {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zarray", zarray("<i4", c(2, 3), c(2, 3), order = "F"))
  write_chunk(root, "0.0", 1:6, 4L)
  expect_equal(open_zarr(root)$root$read(), matrix(1:6, 2, 3))
})

test_that("v2 '/' dimension separator and multiple chunks", {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zarray", zarray("<i4", c(2, 4), c(2, 2), extra = ', "dimension_separator": "/"'))
  write_chunk(root, "0/0", c(1L, 2L, 5L, 6L), 4L)  # C order within each chunk
  write_chunk(root, "0/1", c(3L, 4L, 7L, 8L), 4L)
  expect_equal(open_zarr(root)$root$read(), matrix(1:8, 2, 4, byrow = TRUE))
})

test_that("v2 missing chunk reads as NA", {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zarray", zarray("<i4", 4, 2, fill = "-1"))
  write_chunk(root, "0", c(1L, 2L), 4L)
  expect_equal(open_zarr(root)$root$read(), c(1L, 2L, NA, NA))
})

test_that("v2 blosc-compressed chunk", {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  write_json_doc(root, ".zarray", sub('"compressor": null',
    '"compressor": {"id": "blosc", "cname": "lz4", "clevel": 5, "shuffle": 1, "blocksize": 0}',
    zarray("<f8", 4, 4), fixed = TRUE))
  raw <- writeBin(c(0.1, 0.2, 0.3, 0.4), raw(), size = 8L, endian = "little")
  writeBin(blosc::blosc_compress(raw, compressor = "lz4", level = 5L, shuffle = "shuffle", typesize = 8L),
           file.path(root, "0"))
  expect_equal(open_zarr(root)$root$read(), c(0.1, 0.2, 0.3, 0.4))
})
