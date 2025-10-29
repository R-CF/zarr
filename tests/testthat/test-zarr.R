test_that("Basic functionality", {
  fn <- tempfile(fileext = '.zarr')

  # Create a Zarr object with a file system store
  z <- create_zarr(fn)
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

  unlink(fn)
})

test_that("Single array Zarr", {
  fn <- tempfile(fileext = '.zarr')
  x <- array(runif(120), c(4, 5, 6))
  z <- as_zarr(x, fn)
  expect_true(inherits(z, 'zarr'))
  expect_null(z$add_group('/', 'no_group_below_array'))
  expect_null(z$groups)
  expect_equal(z$arrays, '/')

  unlink(fn)
})
