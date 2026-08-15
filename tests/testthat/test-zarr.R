test_that("Basic functionality on stores", {
  tests <- function(z) {
    expect_true(inherits(z, 'zarr'))
    expect_equal(z$groups, '/')

    # Create hierarchy of groups
    z$add_group('/', 'grp1')
    z$add_group('/', 'grp2')
    z$add_group('/', 'grp3')
    z$add_group('/grp1', 'subgrp11')
    z$add_group('/grp1/subgrp11', 'subsubgrp111')
    expect_equal(z$groups, c('/', '/grp1', '/grp1/subgrp11', '/grp1/subgrp11/subsubgrp111', '/grp2', '/grp3'))

    expect_null(z[['grp2']])
    grp2 <- z[['/grp2']]
    expect_true(inherits(grp2, 'zarr_group'))
    expect_equal(grp2$name, 'grp2')
    expect_equal(grp2$path, '/grp2')
    expect_equal(grp2$prefix, 'grp2/')
    subgrp21 <- grp2$add_group('subgrp21')
    expect_true(inherits(subgrp21, 'zarr_group'))
    expect_equal(z$groups, c('/', '/grp1', '/grp1/subgrp11', '/grp1/subgrp11/subsubgrp111', '/grp2', '/grp2/subgrp21', '/grp3'))

    # UTF-8 node names
    ms <- subgrp21$add_group('µs')
    ms$add_group('Đà_Lạt')
    DaLat <- z[['/grp2/subgrp21/µs/Đà_Lạt']]
    expect_true(inherits(DaLat, 'zarr_group'))
    expect_equal(DaLat$name, 'Đà_Lạt')
    DaLat$parent$add_group('東京')
    expect_equal(subgrp21$groups, c('/grp2/subgrp21', '/grp2/subgrp21/µs', '/grp2/subgrp21/µs/Đà_Lạt', '/grp2/subgrp21/µs/東京'))
    expect_length(z$groups, 10)

    # Build and add arrays
    arr_def <- array_builder$new()
    arr_def$shape <- c(4, 5, 6)
    arr_def$data_type <- 'int32'
    expect_true(arr_def$is_valid())

    arr211 <- subgrp21$add_array('arr211', arr_def$metadata())
    arr212 <- subgrp21$add_array('arr212', arr_def$metadata())
    expect_equal(z$arrays, c('/grp2/subgrp21/arr211', '/grp2/subgrp21/arr212'))
    expect_null(z$add_array('/grp2/subgrp21/arr211', 'bad', arr_def$metadata()))

    # Navigation from group, relative paths, walking paths
    expect_equal(DaLat$relative_path('/grp2/subgrp21/µs'), '..')
    expect_equal(DaLat$relative_path(arr211), '../../arr211')
    expect_equal(z[['/']]$relative_path('/'), '.')
    expect_identical(DaLat$walk_path(strsplit(DaLat$relative_path(arr212), '/', fixed = T)[[1L]]), arr212)
    expect_error(DaLat$relative_path('../../../../..'))
    expect_equal(DaLat[['../東京']]$name, '東京')
    expect_equal(DaLat[['../../arr212']]$name, 'arr212')

    # Delete individual arrays, terminal groups, sub-trees
    subgrp21$delete('arr211')
    expect_equal(subgrp21$arrays, '/grp2/subgrp21/arr212')
    z$delete_group('/grp3')
    expect_length(z$groups, 9)
    grp1 <- z[['/grp1']]
    expect_length(grp1$groups, 3)
    grp1$delete_all()
    expect_equal(grp1$groups, '/grp1')
    z$delete_group('/', recursive = TRUE)
    expect_equal(z$groups, '/')
    expect_length(z$arrays, 0)
  }

  # Create a Zarr object with a file system store
  fn <- tempfile(fileext = '.zarr')
  z <- create_zarr(fn)
  tests(z)
  unlink(fn)

  # Create a Zarr object with a memory store
  z <- create_zarr()
  tests(z)
})

test_that("Single array Zarr", {
  tests <- function(z) {
    expect_true(inherits(z, 'zarr'))
    expect_null(z$add_group('/', 'no_group_below_array'))
    expect_null(z$groups)
    expect_equal(z$arrays, '/')
    expect_true(inherits(z$root, 'zarr_array'))
    expect_equal(z$root$data_type$data_type, 'float64')
  }

  x <- array(runif(120), c(4, 5, 6))

  # File store
  fn <- tempfile(fileext = '.zarr')
  z <- as_zarr(x, location = fn)
  tests(z)
  unlink(fn)

  # Memory store
  z <- as_zarr(x)
  tests(z)
})

test_that("Optimal chunking", {
  # Errors on mismatched dimensions and weights
  expect_error(optimal_chunking(c(100L, 200L, 300L), c(1, 1)))
  expect_error(optimal_chunking(c(100L, 200L, 300L), c(1, 1, 1, 1)))

  # Errors on negative weights"
  expect_error(optimal_chunking(c(100L, 200L, 300L), c(1, -1, 1)))

  # Defaults to equal weights when weights is missing
  dim_sizes <- c(2000L, 2000L, 2000L)
  r <- optimal_chunking(dim_sizes)
  expect_equal(r[1], r[2])
  expect_equal(r[2], r[3])

  # Returns integer type
  r <- optimal_chunking(dim_sizes, c(1, 1, 1))
  expect_type(r, "integer")
  expect_length(r, 3L)

  # Weights must be positive
  expect_error(optimal_chunking(dim_sizes, c(0, 2, 2)))

  # Chunk sizes never exceed the corresponding dimension size
  dim_sizes <- c(50000L, 350L, 123L)
  weights   <- c(1.5, 1.5, 1)
  r <- optimal_chunking(dim_sizes, weights)
  expect_true(all(r <= dim_sizes))
  expect_true(all(r >= 1L))

  # All size-1 dimensions short-circuits to dim_sizes, as integer
  dim_sizes <- c(1L, 1L, 1L)
  r <- optimal_chunking(dim_sizes, c(1, 1, 1))
  expect_equal(r, as.integer(dim_sizes))
  expect_type(r, "integer")

  # Size-1 dimensions are always chunked as 1L, regardless of weight", {
  dim_sizes <- c(1L, 2000L, 2000L)
  r <- optimal_chunking(dim_sizes, c(5, 1, 1))
  expect_equal(r[1], 1L)

  # Size-1 dimension's weight does not dilute the budget for other dims
  # Weight on the degenerate dim should be excluded from W entirely
  dim_sizes <- c(1L, 2000L, 2000L)
  r_low  <- optimal_chunking(dim_sizes, c(0.01, 1, 1))
  r_high <- optimal_chunking(dim_sizes, c(50,   1, 1))
  # Since the degenerate dim's weight never counts toward W, the result
  # for the non-degenerate dims should be identical regardless of its value
  expect_equal(r_low[2:3], r_high[2:3])

  # Single-dimension array chunks to min(chunk_values, dim_size)
  r_small <- optimal_chunking(100L, 1, chunk_values = 4L * 1024L * 1024L)
  expect_equal(r_small, 100L)  # whole (small) dimension fits comfortably

  r_large <- optimal_chunking(10000000L, 1, chunk_values = 1000L)
  expect_true(r_large <= 10000000L)
  expect_true(r_large >= 1L)

  # A dominant weight clips cleanly to the full dimension size
  # t's target size vastly exceeds its actual extent -> clips to dim size
  dim_sizes <- c(9645L, 2000L, 2000L)  # t, x, y
  weights   <- c(3, 0.5, 0.5)
  r <- optimal_chunking(dim_sizes, weights)
  expect_equal(r[1], 9645L)

  # Product of chunk sizes is close to chunk_values in the unclipped case
  dim_sizes <- c(2000L, 2000L, 2000L)
  weights   <- c(1, 1, 1)
  chunk_values <- 4L * 1024L * 1024L
  r <- optimal_chunking(dim_sizes, weights, chunk_values)
  # allow generous tolerance for flooring + the alignment pass
  expect_true(prod(r) > chunk_values * 0.8)
  expect_true(prod(r) <= chunk_values * 1.2)

  # Higher relative weight yields a larger chunk along that dimension
  dim_sizes <- c(2000L, 2000L)
  r <- optimal_chunking(dim_sizes, c(3, 1))
  expect_true(r[1] > r[2])

  # Alignment collapses a near-full chunk + tiny remainder into one chunk
  # regression test: raw target (9410) is just under the dimension size
  # (9645), which used to leave a chunk of 9410 plus a leftover of 235;
  # the alignment pass should recognize a single chunk covers it better
  dim_size <- 9645L
  r <- optimal_chunking(dim_size, 1, chunk_values = 9410L)
  expect_equal(r, 9645L)

  # Alignment does not increase chunk size beyond the dimension
  dim_sizes <- c(50000L, 350L, 123L)
  weights   <- c(1.5, 1.5, 1)
  r <- optimal_chunking(dim_sizes, weights)
  expect_true(all(r <= dim_sizes))

  # Weights argument order maps positionally to dim_sizes
  dim_sizes <- c(2000L, 500L)
  r1 <- optimal_chunking(dim_sizes, c(3, 1))
  r2 <- optimal_chunking(rev(dim_sizes), c(1, 3))
  expect_equal(r1, rev(r2))
})
