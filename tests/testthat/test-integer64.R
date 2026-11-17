# Characterisation tests for the integer64-backed Zarr data types: int64 and
# uint32 (both have Rtype 'integer64' in zarr_v3_datatypes).
#
# Values are compared through as.character() throughout: it is defined for
# integer64, drops dim, and avoids depending on all.equal() methods.
#
# The test store contains:
#
#   /int64_1d   shape=(10)   dtype=int64   chunks=(5)    chunk 0 = 1:5, chunk 1 absent
#   /int64_2d   shape=(4,6)  dtype=int64   chunks=(2,3)  matrix(1:24, 4, 6)
#   /uint32_1d  shape=(10)   dtype=uint32  chunks=(5)    nothing written

skip_if_not_installed("bit64")

z_i64 <- local({
  z <- create_zarr()

  ab <- define_array('int64', 10L)
  ab$chunk_shape <- 5L
  arr <- z$add_array('/', 'int64_1d', ab)
  arr$write(bit64::as.integer64(1:5), selection = list(1L:5L))

  ab <- define_array('int64', c(4L, 6L))
  ab$chunk_shape <- c(2L, 3L)
  arr <- z$add_array('/', 'int64_2d', ab)
  m64 <- bit64::as.integer64(1:24)  # not matrix(): it would strip the class
  dim(m64) <- c(4L, 6L)
  arr$write(m64, selection = list(1L:4L, 1L:6L))

  ab <- define_array('uint32', 10L)
  ab$chunk_shape <- 5L
  z$add_array('/', 'uint32_1d', ab)

  z
})

# ---------------------------------------------------------------------------
# Result type and shape of reads (this is what the single-chunk short-circuit
# in chunk_grid_regular$read() hands back directly)
# ---------------------------------------------------------------------------

test_that("int64 read returns class integer64", {
  res <- z_i64[['/int64_1d']][1:5]
  expect_s3_class(res, 'integer64')
})

test_that("int64 1-D read within one chunk is a plain vector with the right values", {
  res <- z_i64[['/int64_1d']][2:4]
  expect_null(dim(res))
  expect_identical(as.character(res), as.character(2:4))
})

test_that("int64 2-D read within one chunk keeps its dim and values", {
  res <- z_i64[['/int64_2d']][1:2, 1:3]
  expect_s3_class(res, 'integer64')
  expect_equal(dim(res), c(2L, 3L))
  expect_identical(as.character(res), as.character(matrix(1:24, 4L, 6L)[1:2, 1:3]))
})

test_that("int64 2-D read across chunks keeps its dim and values", {
  res <- z_i64[['/int64_2d']][1:4, 2:5]
  expect_s3_class(res, 'integer64')
  expect_equal(dim(res), c(4L, 4L))
  expect_identical(as.character(res), as.character(matrix(1:24, 4L, 6L)[1:4, 2:5]))
})

# ---------------------------------------------------------------------------
# Fill value / absent chunks
# ---------------------------------------------------------------------------

test_that("int64 absent chunk reads back as integer64", {
  res <- z_i64[['/int64_1d']][6:10]
  expect_s3_class(res, 'integer64')
  expect_null(dim(res))
  expect_length(res, 5L)
})

test_that("int64 absent chunk reads back as NA", {
  res <- z_i64[['/int64_1d']][6:10]
  expect_true(all(is.na(res)))
})

test_that("int64 absent chunk reads back as NA with an explicit fill value", {
  ab <- define_array('int64', 5L)
  ab$fill_value <- -9999
  arr <- create_zarr()$add_array('/', 'x', ab)
  expect_true(all(is.na(arr[])))
})

test_that("int64 NA survives a write/read round trip", {
  arr <- create_zarr()$add_array('/', 'x', define_array('int64', 3L))
  arr$write(bit64::as.integer64(c(1, NA, 3)), selection = list(1L:3L))
  res <- arr[]
  expect_identical(is.na(res), c(FALSE, TRUE, FALSE))
  expect_identical(as.character(res[c(1L, 3L)]), c('1', '3'))
})

# ---------------------------------------------------------------------------
# Writing integer64 input (the codec's integer64 encode branch)
# ---------------------------------------------------------------------------

test_that("int64 accepts integer64 input on write", {
  z <- create_zarr()
  arr <- z$add_array('/', 'x', define_array('int64', 5L))
  expect_no_error(arr$write(bit64::as.integer64(1:5), selection = list(1L:5L)))
  expect_identical(as.character(arr[]), as.character(1:5))
})

test_that("int64 values above 2^53 survive a round trip", {
  z <- create_zarr()
  arr <- z$add_array('/', 'x', define_array('int64', 2L))
  big <- bit64::as.integer64(c('9007199254740993', '-9007199254740993'))
  arr$write(big, selection = list(1L:2L))
  expect_identical(as.character(arr[]), c('9007199254740993', '-9007199254740993'))
})

test_that("int64 read from one array can be written to another", {
  z <- create_zarr()
  dst <- z$add_array('/', 'dst', define_array('int64', 5L))
  dst$write(z_i64[['/int64_1d']][1:5], selection = list(1L:5L))
  expect_identical(as.character(dst[]), as.character(1:5))
})

# ---------------------------------------------------------------------------
# uint32 (Rtype integer64 but 4 bytes on disk)
# ---------------------------------------------------------------------------

test_that("uint32 round trip with integer64 input", {
  z <- create_zarr()
  arr <- z$add_array('/', 'x', define_array('uint32', 5L))
  arr$write(bit64::as.integer64(1:5), selection = list(1L:5L))
  expect_identical(as.character(arr[]), as.character(1:5))
})

test_that("uint32 values above 2^31 round trip", {
  z <- create_zarr()
  arr <- z$add_array('/', 'x', define_array('uint32', 2L))
  arr$write(bit64::as.integer64(c('3000000000', '4000000000')), selection = list(1L:2L))
  expect_identical(as.character(arr[]), c('3000000000', '4000000000'))
})

test_that("uint32 absent chunk reads back as NA", {
  res <- z_i64[['/uint32_1d']][1:5]
  expect_s3_class(res, 'integer64')
  expect_true(all(is.na(res)))
})
