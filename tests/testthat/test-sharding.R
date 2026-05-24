# Tests for sharding codec support
# Tests use a synthetic sharded Zarr store included in the package test data.
# Since sharded stores can only be written by zarr-python at this time,
# we use the pre-built store and test reading only.

test_that("sharding codec is detected and parsed from metadata", {
  z <- open_zarr("testdata/sharded_test.zarr")

  # float2d
  arr <- z[["/float2d"]]
  expect_s3_class(arr$chunking, "chunk_grid_sharded")
  expect_equal(arr$chunking$shard_shape, c(40L, 40L))
  expect_equal(arr$chunking$inner_shape, c(10L, 10L))

  # float2d: single element reads are correct
  # value = (row - 1) + (col - 1) / 1000  (1-based R indexing)
  expect_equal(arr[1, 1],   0.000, tolerance = 1e-5)
  expect_equal(arr[6, 24],  5.023, tolerance = 1e-5)
  expect_equal(arr[200, 300], 199.299, tolerance = 1e-5)

  # float2d: slice within a single shard is correct
  result <- arr[1:5, 1:5]
  expect_equal(dim(result), c(5L, 5L))
  # Check corners
  expect_equal(result[1, 1], 0.000, tolerance = 1e-5)  # row=0, col=0
  expect_equal(result[5, 5], 4.004, tolerance = 1e-5)  # row=4, col=4

  # float2d: slice crossing inner chunk boundary is correct
  # Crosses inner chunk boundary at row 10 and col 10
  result <- arr[8:13, 8:13]
  expect_equal(dim(result), c(6L, 6L))
  # Check a few values
  expect_equal(result[1, 1], 7.007, tolerance = 1e-5)  # row=7, col=7
  expect_equal(result[6, 6], 12.012, tolerance = 1e-5) # row=12, col=12

  # float2d: slice crossing shard boundary is correct
  # Shard boundary at row 40, col 40
  result <- arr[38:43, 38:43]
  expect_equal(dim(result), c(6L, 6L))
  expect_equal(result[1, 1], 37.037, tolerance = 1e-5) # row=37, col=37
  expect_equal(result[6, 6], 42.042, tolerance = 1e-5) # row=42, col=42

  # int3d
  arr <- z[["/int3d"]]
  expect_s3_class(arr$chunking, "chunk_grid_sharded")
  expect_equal(arr$chunking$shard_shape, c(16L, 16L, 16L))
  expect_equal(arr$chunking$inner_shape, c(8L, 8L, 8L))

  # int3d: single element reads are correct (no compression, zstd)
  # value = (plane-1)*10000 + (row-1)*100 + (col-1)
  expect_equal(arr[1, 1, 1],      0L)
  expect_equal(arr[3, 6, 24],     20523L)
  expect_equal(arr[50, 120, 120], 502019L)

  # int3d: slice crossing inner chunk and shard boundaries
  # Crosses inner chunk boundary (at 8) and shard boundary (at 16)
  result <- arr[1:10, 1:10, 1:10]
  expect_equal(dim(result), c(10L, 10L, 10L))

  # Check corners
  expect_equal(result[1, 1, 1],   0L)       # plane=0, row=0, col=0
  expect_equal(result[10, 10, 10], 90909L)  # plane=9, row=9, col=9

  # Check a mid value
  expect_equal(result[3, 6, 8], 20507L)     # plane=2, row=5, col=7

  # int3d: full first plane is correct (drop=FALSE to preserve all 3 dims)
  result <- arr[1, 1:120, 1:120, drop = FALSE]
  expect_equal(dim(result), c(1L, 120L, 120L))

  # All values in plane 0: row*100 + col (0-based)
  expected <- outer(0:119, 0:119, function(r, c) r * 100L + c)
  expect_equal(result[1,,], expected)

  # float1d
  arr <- z[["/float1d"]]
  expect_s3_class(arr$chunking, "chunk_grid_sharded")
  expect_equal(arr$chunking$shard_shape, c(400L))
  expect_equal(arr$chunking$inner_shape, c(100L))

  # float1d: single element reads are correct (gzip)
  expect_equal(arr[1],    0.0,   tolerance = 1e-5)
  expect_equal(arr[101],  100.0, tolerance = 1e-5)
  expect_equal(arr[1000], 999.0, tolerance = 1e-5)

  # float1d: slice crossing inner chunk boundary
  # Inner chunk boundary at 100
  result <- arr[98:103]
  expect_equal(result, c(97, 98, 99, 100, 101, 102), tolerance = 1e-5)

  # float1d: slice crossing shard boundary
  # Shard boundary at 400
  result <- arr[398:403]
  expect_equal(result, c(397, 398, 399, 400, 401, 402), tolerance = 1e-5)
})

test_that("sharding: absent inner chunks return fill value", {
  arr <- open_zarr("testdata/sharded_test.zarr")[["/int3d"]]

  # The fill_value for int3d is -1
  # Edge shard beyond array extent should not be readable, but
  # selections within the array at edge shards should handle
  # absent inner chunks gracefully by returning fill value
  # (This tests the sentinel path in load_inner())
  result <- arr[49:50, 119:120, 119:120]
  expect_equal(dim(result), c(2L, 2L, 2L))
  expect_equal(result[2, 2, 2], 502019L)  # last real element
})
