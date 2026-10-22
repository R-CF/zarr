# Tests for the chunk grid: the `grid` field of the chunking scheme and its
# maintenance across operations that change the shape of the array.

test_that("grid: regular chunk grid with an aligned shape", {
  cg <- chunk_grid_regular$new(c(6L, 4L), c(2L, 2L))
  expect_equal(cg$grid, c(3L, 2L))
})

test_that("grid: regular chunk grid with a partial last chunk", {
  cg <- chunk_grid_regular$new(c(7L, 5L), c(2L, 2L))
  expect_equal(cg$grid, c(4L, 3L))
})

test_that("grid: chunk larger than the array is a single chunk", {
  cg <- chunk_grid_regular$new(c(3L, 10L), c(5L, 10L))
  expect_equal(cg$grid, c(1L, 1L))
})

test_that("grid: scalar array has an empty grid", {
  cg <- chunk_grid_regular$new(NA_integer_)
  expect_identical(cg$grid, integer(0))
  expect_null(cg$array_shape)
})

test_that("grid: is integer", {
  cg <- chunk_grid_regular$new(c(7L, 5L), c(2L, 2L))
  expect_type(cg$grid, 'integer')
})

test_that("grid: chunk_keys() enumerates the grid", {
  z <- create_zarr()
  def <- define_array('int32', c(5L, 3L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'keys', def)
  expect_length(arr$chunking$chunk_keys(), prod(arr$chunking$grid))
  expect_length(arr$chunking$chunk_keys(), 6L)
})

test_that("grid: updated when growing the high end", {
  z <- create_zarr()
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'grow_high', def)
  arr$resize(high = c(1L, 4L))
  expect_equal(arr$shape, c(7L, 8L))
  expect_equal(arr$chunking$grid, c(4L, 4L))
  expect_equal(arr$chunking$array_shape, arr$shape)
})

test_that("grid: updated when shrinking the high end", {
  z <- create_zarr()
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'shrink_high', def)
  arr$resize(high = c(-3L, 0L))
  expect_equal(arr$chunking$grid, c(2L, 2L))
})

test_that("grid: updated when growing the low end", {
  z <- create_zarr()
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'grow_low', def)
  arr$resize(low = c(1L, 0L))  # rounded outward to one whole chunk
  expect_equal(arr$shape, c(8L, 4L))
  expect_equal(arr$chunking$grid, c(4L, 2L))
})

test_that("grid: unchanged by a failed resize", {
  z <- create_zarr()
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'bad_resize', def)
  expect_error(arr$resize(high = c(-6L, 0L)), 'non-positive')
  expect_equal(arr$chunking$grid, c(3L, 2L))
})

test_that("grid: promote() inserts a single chunk", {
  z <- create_zarr()
  def <- define_array('int32', c(5L, 3L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'promote_grid', def)
  arr$promote(dimension = 2L)
  expect_equal(arr$chunking$grid, c(3L, 1L, 2L))
})

test_that("grid: promote() of a scalar array", {
  z <- create_zarr()
  meta <- list(zarr_format = 3L, node_type = 'array', shape = list(),
               data_type = 'int32', fill_value = -2147483647L,
               chunk_grid = list(name = 'regular', configuration = list(chunk_shape = list())))
  sc <- z$add_array('/', 'sc_grid', meta)
  sc$promote(dimension = 1L, length = 4L)
  expect_equal(sc$chunking$grid, 1L)
})

test_that("resize: pending edits are persisted before chunks are moved", {
  z <- create_zarr()
  def <- define_array('int32', c(4L, 2L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'pending', def)
  x <- array(1:8L, c(4L, 2L))
  arr$write(x, flush = FALSE)
  arr$resize(low = c(2L, 0L))
  expect_equal(arr$read(list(c(3L, 6L), c(1L, 2L))), x)
  expect_true(all(is.na(arr$read(list(c(1L, 2L), c(1L, 2L))))))
})

test_that("sharding: the grid is the grid of shards", {
  skip_if_not_installed("zlib")
  arr <- open_zarr("testdata/sharded_test.zarr")[["/float2d"]]
  expect_s3_class(arr$chunking, "chunk_grid_regular")
  expect_equal(arr$chunking$grid, (arr$shape - 1L) %/% arr$chunking$chunk_shape + 1L)
})

test_that("sharding: writing raises an error", {
  skip_if_not_installed("zlib")
  arr <- open_zarr("testdata/sharded_test.zarr")[["/float2d"]]
  expect_error(arr$chunking$write(matrix(0, 1L, 1L), c(1L, 1L), c(1L, 1L)), 'not supported')
})

test_that("sharding: the chunking scheme keeps its own name", {
  skip_if_not_installed("zlib")
  arr <- open_zarr("testdata/sharded_test.zarr")[["/float2d"]]
  expect_equal(arr$chunking$name, 'sharding_indexed')
})
