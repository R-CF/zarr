# Tests for parallel and sequential reading of Zarr arrays
#
# These tests verify that:
#   1. Sequential and parallel reads produce identical results
#   2. The parallel threshold option is respected
#   3. Parallel execution requires future.apply to be available
#   4. Results are correct for both regular and sharded arrays
#
# All tests use local stores to avoid HTTP dependency in R CMD check.
# The parallel plan is always reset to sequential after each test to avoid
# side effects on subsequent tests.

# Helper: reset to sequential plan and restore threshold on exit
with_sequential <- function(code) {
  old_threshold <- Zarr.options$parallel_threshold
  on.exit({
    if (requireNamespace('future', quietly = TRUE))
      future::plan('sequential')
    Zarr.options$parallel_threshold <- old_threshold
  })
  force(code)
}

# ---------------------------------------------------------------------------
# Regular chunked array — africa.zarr
# ---------------------------------------------------------------------------

test_that("regular array: sequential and parallel reads are identical", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z <- open_zarr(system.file("extdata/africa.zarr", package = 'zarr'))
    arr <- z[["/tas"]]

    # Sequential baseline
    future::plan('sequential')
    Zarr.options$parallel_threshold <- 1L  # force parallel path for all reads
    r_seq <- arr[]

    # Parallel read
    future::plan('multisession', workers = 2L)
    r_par <- arr[]

    expect_identical(r_seq, r_par)
  })
})

test_that("regular array: parallel threshold prevents parallelism for small arrays", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z <- open_zarr(system.file("extdata/africa.zarr", package = 'zarr'))
    arr <- z[["/tas"]]

    future::plan('multisession', workers = 2L)

    # Threshold above number of chunks: should use sequential path
    Zarr.options$parallel_threshold <- .Machine$integer.max
    r1 <- arr[]

    # Threshold below number of chunks: should use parallel path
    Zarr.options$parallel_threshold <- 1L
    r2 <- arr[]

    expect_identical(r1, r2)
  })
})

test_that("regular array: parallel read without future.apply falls back to sequential", {
  with_sequential({
    z <- open_zarr(system.file("extdata/africa.zarr", package = 'zarr'))
    arr <- z[["/tas"]]

    # Set threshold low so parallel would be used if available
    Zarr.options$parallel_threshold <- 1L

    # Result should be correct regardless of whether future.apply is installed
    r <- arr[]
    expect_true(is.array(r) || is.vector(r))
  })
})

test_that("regular array: partial selection is identical in sequential and parallel", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z <- open_zarr(system.file("extdata/africa.zarr", package = 'zarr'))
    arr <- z[["/tas"]]

    Zarr.options$parallel_threshold <- 1L

    future::plan('sequential')
    r_seq <- arr[1:10, 1:10, 1:2]

    future::plan('multisession', workers = 2L)
    r_par <- arr[1:10, 1:10, 1:2]

    expect_identical(r_seq, r_par)
  })
})

# ---------------------------------------------------------------------------
# Sharded array — sharded_test.zarr
# ---------------------------------------------------------------------------

test_that("sharded array: sequential and parallel reads are identical (float2d)", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z   <- open_zarr(test_path("testdata/sharded_test.zarr"))
    arr <- z[["/float2d"]]

    Zarr.options$parallel_threshold <- 1L

    # Selection crossing multiple shards
    future::plan('sequential')
    r_seq <- arr[38:43, 38:43]

    future::plan('multisession', workers = 2L)
    r_par <- arr[38:43, 38:43]

    expect_identical(r_seq, r_par)
  })
})

test_that("sharded array: sequential and parallel reads are identical (int3d)", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z   <- open_zarr(test_path("testdata/sharded_test.zarr"))
    arr <- z[["/int3d"]]

    Zarr.options$parallel_threshold <- 1L

    # Selection crossing shard boundaries in all 3 dimensions
    future::plan('sequential')
    r_seq <- arr[15:18, 15:18, 15:18]

    future::plan('multisession', workers = 2L)
    r_par <- arr[15:18, 15:18, 15:18]

    expect_identical(r_seq, r_par)
  })
})

test_that("sharded array: sequential and parallel reads are identical (float1d)", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z   <- open_zarr(test_path("testdata/sharded_test.zarr"))
    arr <- z[["/float1d"]]

    Zarr.options$parallel_threshold <- 1L

    # Selection crossing shard boundary at 400
    future::plan('sequential')
    r_seq <- arr[398:403]

    future::plan('multisession', workers = 2L)
    r_par <- arr[398:403]

    expect_identical(r_seq, r_par)
  })
})

test_that("sharded array: parallel threshold is respected", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z   <- open_zarr(test_path("testdata/sharded_test.zarr"))
    arr <- z[["/float2d"]]

    future::plan('multisession', workers = 2L)

    # High threshold: sequential path
    Zarr.options$parallel_threshold <- .Machine$integer.max
    r1 <- arr[38:43, 38:43]

    # Low threshold: parallel path
    Zarr.options$parallel_threshold <- 1L
    r2 <- arr[38:43, 38:43]

    expect_identical(r1, r2)
  })
})

test_that("sharded array: full array read is identical in sequential and parallel", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z   <- open_zarr(test_path("testdata/sharded_test.zarr"))
    arr <- z[["/int3d"]]

    Zarr.options$parallel_threshold <- 1L

    future::plan('sequential')
    r_seq <- arr[]

    future::plan('multisession', workers = 2L)
    r_par <- arr[]

    expect_identical(r_seq, r_par)
  })
})

# ---------------------------------------------------------------------------
# Parallel threshold option
# ---------------------------------------------------------------------------

test_that("parallel threshold option can be set and retrieved", {
  old <- Zarr.options$parallel_threshold
  on.exit(Zarr.options$parallel_threshold <- old)

  Zarr.options$parallel_threshold <- 16L
  expect_equal(Zarr.options$parallel_threshold, 16L)

  Zarr.options$parallel_threshold <- .Machine$integer.max
  expect_equal(Zarr.options$parallel_threshold, .Machine$integer.max)
})

test_that("parallel threshold defaults to a positive integer", {
  expect_true(is.numeric(Zarr.options$parallel_threshold))
  expect_true(Zarr.options$parallel_threshold > 0L)
})

# ---------------------------------------------------------------------------
# Correctness under parallel execution
# ---------------------------------------------------------------------------

test_that("sharded array: values are correct under parallel execution (int3d)", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z   <- open_zarr(test_path("testdata/sharded_test.zarr"))
    arr <- z[["/int3d"]]

    Zarr.options$parallel_threshold <- 1L
    future::plan('multisession', workers = 2L)

    # value = (plane-1)*10000 + (row-1)*100 + (col-1)
    expect_equal(arr[1, 1, 1],       0L)
    expect_equal(arr[3, 6, 24],  20523L)
    expect_equal(arr[50, 120, 120], 502019L)

    # Slice crossing shard boundaries
    result <- arr[15:18, 15:18, 15:18]
    expect_equal(dim(result), c(4L, 4L, 4L))
    # plane=14, row=14, col=14 (0-based) -> 140000 + 1400 + 14 = 141414
    expect_equal(result[1, 1, 1], 141414L)
  })
})

test_that("regular array: values are correct under parallel execution", {
  skip_if_not_installed('future')
  skip_if_not_installed('future.apply')

  with_sequential({
    z <- open_zarr(system.file("extdata/africa.zarr", package = 'zarr'))
    arr <- z[["/tas"]]

    Zarr.options$parallel_threshold <- 1L
    future::plan('multisession', workers = 2L)

    r_seq_ref <- {
      future::plan('sequential')
      arr[]
    }

    future::plan('multisession', workers = 2L)
    r_par <- arr[]

    expect_equal(r_par, r_seq_ref)
  })
})
