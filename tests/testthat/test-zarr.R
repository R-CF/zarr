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

    # Navigation from group, relative paths
    expect_equal(DaLat[['..']]$name, 'µs')
    expect_equal(DaLat[['../..']]$name, 'subgrp21')
    expect_equal(DaLat[['../../../..']]$path, '/')
    expect_null(DaLat[['../../../../..']])
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

test_that("HTTP store", {
  z <- open_zarr("https://data.earthdatahub.destine.eu/public/test-dataset-v0.zarr")
  expect_equal(z$arrays, c("/age_band_lower_bound", "/demographic_totals", "/latitude", "/longitude", "/year"))
  lat <- z[["/latitude"]]
  expect_equal(lat$shape, 720)
  expect_equal(lat$data_type$data_type, "float64")
  expect_equal(range(lat[]), c(-89.75, 90))
  expect_true(all(diff(lat[]) == -0.25))
  age <- z[["/age_band_lower_bound"]]
  expect_equal(age$data_type$data_type, "int64")
  expect_equal(age[], seq(bit64::as.integer64(0), 65, by = 5))
  yr <- z[["/year"]]
  expect_equal(yr$data_type$data_type, "int64")
  expect_equal(yr[], seq(bit64::as.integer64(1950), 2020))
})
