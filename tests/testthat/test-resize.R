# Tests for zarr_array$resize() and zarr_array$promote().
#
# Array/store combinations exercised: local file system (default '.'
# separator and, separately, '/' separator to reach the prefix-rename fast
# path), in-memory store, and the pre-built sharded test fixture.

test_that("resize: growing and shrinking the high end", {
  z <- create_zarr()
  x <- array(1:24L, c(6L, 4L))  # x[r, c] via seq_len, column-major

  # --- grow: new region reads NA, existing data untouched -----------------
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'grow', def)
  arr$write(x)

  arr$resize(high = c(4L, 2L))
  expect_equal(arr$shape, c(10L, 6L))
  expected <- array(NA_integer_, c(10L, 6L))
  expected[1:6, 1:4] <- x
  expect_equal(arr$read(), expected)

  # --- shrink, chunk-aligned: chunks holding real data are deleted --------
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'shrink_aligned', def)
  arr$write(x)

  expect_true(arr$store$exists('shrink_aligned/c.2.0'))
  expect_true(arr$store$exists('shrink_aligned/c.2.1'))
  arr$resize(high = c(-2L, 0L))  # 6 -> 4, removes chunk row 2 (rows 5:6)
  expect_equal(arr$shape, c(4L, 4L))
  expect_equal(arr$read(), x[1:4, ])
  expect_false(arr$store$exists('shrink_aligned/c.2.0'))
  expect_false(arr$store$exists('shrink_aligned/c.2.1'))

  # --- shrink, non-aligned: boundary chunk survives with its tail NA'd,
  # not merely hidden by the shape check -- prove it by growing back and
  # confirming the regrown cell reads NA rather than the stale old value ---
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'shrink_clip', def)
  arr$write(x)

  arr$resize(high = c(-1L, 0L))   # 6 -> 5, chunk row 2 (rows 5:6) survives, row 6 clipped
  expect_equal(arr$shape, c(5L, 4L))
  expect_equal(arr$read(), x[1:5, ])

  arr$resize(high = c(1L, 0L))    # back to 6 rows
  expect_equal(arr$shape, c(6L, 4L))
  result <- arr$read()
  expect_equal(result[1:5, ], x[1:5, ])
  expect_true(all(is.na(result[6, ])))  # would be x[6,] = c(6,12,18,24) if not clipped
})

test_that("resize: growing and shrinking the low end", {
  z <- create_zarr()
  x <- array(1:24L, c(6L, 4L))

  # --- chunk-aligned low-end grow then shrink: chunks are renamed, not
  # rewritten; the vacated low chunk is never created on disk -------------
  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'low', def)
  arr$write(x)

  arr$resize(low = c(2L, 0L))  # 6 -> 8, shift 1 chunk
  expect_equal(arr$shape, c(8L, 4L))
  expected <- array(NA_integer_, c(8L, 4L))
  expected[3:8, ] <- x
  expect_equal(arr$read(), expected)
  expect_false(arr$store$exists('low/c.0.0'))
  expect_true(arr$store$exists('low/c.1.0'))

  expect_true(arr$store$exists('low/c.3.0'))
  arr$resize(low = c(-4L, 0L))  # 8 -> 4, removes 2 chunks from the low end
  expect_equal(arr$shape, c(4L, 4L))
  expect_equal(arr$read(), x[3:6, ])
  expect_false(arr$store$exists('low/c.3.0'))
  expect_true(arr$store$exists('low/c.1.0'))

  # --- non-chunk-aligned low deltas round outward: more space added when
  # growing, less removed when shrinking -----------------------------------
  def <- define_array('int32', 6L); def$chunk_shape <- 2L
  arr1d <- z$add_array('/', 'low1d', def)
  arr1d$write(1:6L)

  arr1d$resize(low = 3L)  # requests 3, chunk size 2 -> rounds up to 4
  expect_equal(arr1d$shape, 10L)
  expect_equal(arr1d$read(), c(rep(NA_integer_, 4L), 1:6L))

  arr1d$resize(low = -3L)  # requests removing 3, rounds down to 2
  expect_equal(arr1d$shape, 8L)
  expect_equal(arr1d$read(), c(NA_integer_, NA_integer_, 1:6L))
})

test_that("resize: independent and simultaneous shifts across dimensions", {
  z <- create_zarr()
  x <- array(1:24L, c(6L, 4L))

  def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'multi', def)
  arr$write(x)

  # grow low on dim 1, shrink high on dim 2, one call, one dimension shifted
  arr$resize(low = c(2L, 0L), high = c(0L, -2L))
  expect_equal(arr$shape, c(8L, 2L))
  expected1 <- array(NA_integer_, c(8L, 2L))
  expected1[3:8, ] <- x[1:6, 1:2]
  expect_equal(arr$read(), expected1)

  # now shift BOTH dimensions' low end at once: exercises the general
  # rename ordering (dot(old_cidx, shift) descending), not the single-
  # dimension shortcut
  arr$resize(low = c(2L, 2L))
  expect_equal(arr$shape, c(10L, 4L))
  expected2 <- array(NA_integer_, c(10L, 4L))
  expected2[3:10, 3:4] <- expected1
  expect_equal(arr$read(), expected2)
})

test_that("resize: '/' chunk-key separator takes the prefix-rename fast path", {
  x <- array(1:24L, c(6L, 4L))
  expected <- array(NA_integer_, c(8L, 4L))
  expected[3:8, ] <- x

  make_meta <- function(sep) {
    def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
    meta <- def$metadata()
    meta$chunk_key_encoding <- list(name = 'default', configuration = list(separator = sep))
    meta
  }

  # Local store, '/' separator: eligible for the directory-collapse path.
  fn <- tempfile(fileext = '.zarr')
  zl <- create_zarr(fn)
  arr_l <- zl$add_array('/', 'sepL', make_meta('/'))
  arr_l$write(x)
  expect_true(arr_l$store$supports_prefix_rename)
  expect_equal(arr_l$chunk_separator, '/')

  expect_true(dir.exists(file.path(fn, 'sepL', 'c', '0')))
  arr_l$resize(low = c(2L, 0L))
  expect_equal(arr_l$read(), expected)
  expect_false(dir.exists(file.path(fn, 'sepL', 'c', '0')))
  expect_true(dir.exists(file.path(fn, 'sepL', 'c', '3')))
  unlink(fn, recursive = TRUE)

  # Memory store: no prefix rename support regardless of separator, falls
  # through to the general per-chunk path. Must produce the same result.
  zm <- create_zarr()
  arr_m <- zm$add_array('/', 'sepM', make_meta('/'))
  arr_m$write(x)
  expect_false(arr_m$store$supports_prefix_rename)

  arr_m$resize(low = c(2L, 0L))
  expect_equal(arr_m$read(), expected)
  expect_equal(arr_m$read(), arr_l_expected <- expected)  # same as the local-store result above
})

test_that("resize: input validation", {
  z <- create_zarr()

  # Note: a true rank-0 scalar array can't currently be constructed via the
  # public API at all -- array_builder$is_valid() requires a non-empty codec
  # list, and update_codecs() never populates one for a scalar shape (it
  # also can't distinguish "shape not yet set" from "shape set to scalar",
  # since both are stored as NA_integer_). The `if (!nd) stop(...)` guard in
  # resize() is written defensively for when that's fixed, but is
  # untestable until then.

  def <- define_array('int32', c(4L, 4L)); def$chunk_shape <- c(2L, 2L)
  arr <- z$add_array('/', 'valid', def)
  expect_error(arr$resize(low = c(1L, 1L, 1L)), 'one element per dimension')
  expect_error(arr$resize(high = c(-4L, 0L)), 'non-positive extent')
})

test_that("resize: sharded arrays", {
  src <- 'testdata/sharded_test.zarr'
  parent <- tempfile()
  dir.create(parent)
  file.copy(src, parent, recursive = TRUE)
  dst <- file.path(parent, basename(src))

  z <- open_zarr(dst)
  arr <- z[['/float2d']]
  expect_equal(arr$shape, c(200L, 300L))

  # grow: no shard touched, metadata-only
  arr$resize(high = c(40L, 0L))
  expect_equal(arr$shape, c(240L, 300L))
  expect_equal(arr[1, 1], 0.000, tolerance = 1e-5)

  # shrink, shard-aligned: whole shards renamed/deleted, no decode needed
  z2 <- open_zarr(dst2 <- { d <- tempfile(); dir.create(d); file.copy(src, d, recursive = TRUE); file.path(d, basename(src)) })
  arr2 <- z2[['/float2d']]
  expect_true(arr2$store$exists('float2d/c/4/0'))
  arr2$resize(high = c(-40L, 0L))  # 200 -> 160, exact multiple of the 40-shard
  expect_equal(arr2$shape, c(160L, 300L))
  expect_equal(arr2[160, 1], 159.000, tolerance = 1e-5)
  expect_false(arr2$store$exists('float2d/c/4/0'))

  # shrink, not shard-aligned: sharded arrays can't clip a partial shard yet
  z3 <- open_zarr(dst3 <- { d <- tempfile(); dir.create(d); file.copy(src, d, recursive = TRUE); file.path(d, basename(src)) })
  arr3 <- z3[['/float2d']]
  expect_error(arr3$resize(high = c(0L, -10L)), 'not supported')  # 300 -> 290, 290 %% 40 != 0
})

test_that("promote: scalar array becomes a functional rank-1 array", {
  z <- create_zarr()
  meta <- list(zarr_format = 3L, node_type = 'array', shape = list(),
               data_type = 'int32', fill_value = -2147483647L,
               chunk_grid = list(name = 'regular', configuration = list(chunk_shape = list())))
  sc <- z$add_array('/', 'sc_promote', meta)

  sc$promote(dimension = 1L)
  expect_equal(sc$shape, 1L)
  expect_true('bytes' %in% vapply(sc$codecs, function(c) c$name, character(1L)))
  expect_true(is.na(sc$read()))

  sc$write(42L)
  expect_equal(sc$read(), 42L)
})

test_that("promote: inserting a new axis preserves data and codecs", {
  z <- create_zarr()
  x <- array(1:12L, c(4L, 3L))

  def <- define_array('int32', c(4L, 3L)); def$chunk_shape <- c(4L, 3L)  # keeps the default blosc codec
  arr <- z$add_array('/', 'lead', def)
  arr$write(x)
  expect_true('blosc' %in% vapply(arr$codecs, function(c) c$name, character(1L)))

  arr$promote(dimension = 1L)  # leading dimension, the CF "insert time" case
  expect_equal(arr$shape, c(1L, 4L, 3L))
  expect_equal(arr$chunking$chunk_shape, c(1L, 4L, 3L))
  expect_true('blosc' %in% vapply(arr$codecs, function(c) c$name, character(1L)))
  expected <- x; dim(expected) <- c(1L, 4L, 3L)
  expect_equal(arr$read(), expected)

  def2 <- define_array('int32', c(4L, 3L)); def2$chunk_shape <- c(4L, 3L)
  arr2 <- z$add_array('/', 'trail', def2)
  arr2$write(x)
  arr2$promote(dimension = 3L)  # trailing dimension
  expect_equal(arr2$shape, c(4L, 3L, 1L))
  expected2 <- x; dim(expected2) <- c(4L, 3L, 1L)
  expect_equal(arr2$read(), expected2)

  # validation
  expect_error(arr2$promote(dimension = 5L), 'between 1 and')

  sh <- open_zarr('testdata/sharded_test.zarr')[['/float2d']]
  expect_error(sh$promote(dimension = 1L), 'sharded')
})

test_that("resize: growing and shrinking the high end", {
  run_on_stores <- function(tests) {
    tests(create_zarr())                          # memory
    fn <- tempfile(fileext = '.zarr')
    tests(create_zarr(fn))                         # local, default '.' separator
    unlink(fn, recursive = TRUE)
  }

  tests <- function(z) {
    x <- array(1:24L, c(6L, 4L))  # x[r, c] via seq_len, column-major

    # --- grow: new region reads NA, existing data untouched ---------------
    def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
    arr <- z$add_array('/', 'grow', def)
    arr$write(x)

    arr$resize(high = c(4L, 2L))
    expect_equal(arr$shape, c(10L, 6L))
    expected <- array(NA_integer_, c(10L, 6L))
    expected[1:6, 1:4] <- x
    expect_equal(arr$read(), expected)

    # --- shrink, chunk-aligned: chunks holding real data are deleted ------
    def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
    arr <- z$add_array('/', 'shrink_aligned', def)
    arr$write(x)

    expect_true(arr$store$exists('shrink_aligned/c.2.0'))
    expect_true(arr$store$exists('shrink_aligned/c.2.1'))
    arr$resize(high = c(-2L, 0L))  # 6 -> 4, removes chunk row 2 (rows 5:6)
    expect_equal(arr$shape, c(4L, 4L))
    expect_equal(arr$read(), x[1:4, ])
    expect_false(arr$store$exists('shrink_aligned/c.2.0'))
    expect_false(arr$store$exists('shrink_aligned/c.2.1'))

    # --- shrink, non-aligned: boundary chunk survives with its tail NA'd --
    def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
    arr <- z$add_array('/', 'shrink_clip', def)
    arr$write(x)

    arr$resize(high = c(-1L, 0L))   # 6 -> 5, chunk row 2 (rows 5:6) survives, row 6 clipped
    expect_equal(arr$shape, c(5L, 4L))
    expect_equal(arr$read(), x[1:5, ])

    arr$resize(high = c(1L, 0L))    # back to 6 rows
    expect_equal(arr$shape, c(6L, 4L))
    result <- arr$read()
    expect_equal(result[1:5, ], x[1:5, ])
    expect_true(all(is.na(result[6, ])))  # would be x[6,] = c(6,12,18,24) if not clipped
  }

  run_on_stores(tests)
})

test_that("resize: growing and shrinking the low end", {
  run_on_stores <- function(tests) {
    tests(create_zarr())
    fn <- tempfile(fileext = '.zarr')
    tests(create_zarr(fn))
    unlink(fn, recursive = TRUE)
  }

  tests <- function(z) {
    x <- array(1:24L, c(6L, 4L))

    # --- chunk-aligned low-end grow then shrink: chunks renamed, not
    # rewritten; the vacated low chunk is never created on disk -----------
    def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
    arr <- z$add_array('/', 'low', def)
    arr$write(x)

    arr$resize(low = c(2L, 0L))  # 6 -> 8, shift 1 chunk
    expect_equal(arr$shape, c(8L, 4L))
    expected <- array(NA_integer_, c(8L, 4L))
    expected[3:8, ] <- x
    expect_equal(arr$read(), expected)
    expect_false(arr$store$exists('low/c.0.0'))
    expect_true(arr$store$exists('low/c.1.0'))

    expect_true(arr$store$exists('low/c.3.0'))
    arr$resize(low = c(-4L, 0L))  # 8 -> 4, removes 2 chunks from the low end
    expect_equal(arr$shape, c(4L, 4L))
    expect_equal(arr$read(), x[3:6, ])
    expect_false(arr$store$exists('low/c.3.0'))
    expect_true(arr$store$exists('low/c.1.0'))

    # --- non-chunk-aligned low deltas round outward ------------------------
    def <- define_array('int32', 6L); def$chunk_shape <- 2L
    arr1d <- z$add_array('/', 'low1d', def)
    arr1d$write(1:6L)

    arr1d$resize(low = 3L)  # requests 3, chunk size 2 -> rounds up to 4
    expect_equal(arr1d$shape, 10L)
    expect_equal(arr1d$read(), c(rep(NA_integer_, 4L), 1:6L))

    arr1d$resize(low = -3L)  # requests removing 3, rounds down to 2
    expect_equal(arr1d$shape, 8L)
    expect_equal(arr1d$read(), c(NA_integer_, NA_integer_, 1:6L))
  }

  run_on_stores(tests)
})

test_that("resize: independent and simultaneous shifts across dimensions", {
  run_on_stores <- function(tests) {
    tests(create_zarr())
    fn <- tempfile(fileext = '.zarr')
    tests(create_zarr(fn))
    unlink(fn, recursive = TRUE)
  }

  tests <- function(z) {
    x <- array(1:24L, c(6L, 4L))

    def <- define_array('int32', c(6L, 4L)); def$chunk_shape <- c(2L, 2L)
    arr <- z$add_array('/', 'multi', def)
    arr$write(x)

    # grow low on dim 1, shrink high on dim 2, one call, one dimension shifted
    arr$resize(low = c(2L, 0L), high = c(0L, -2L))
    expect_equal(arr$shape, c(8L, 2L))
    expected1 <- array(NA_integer_, c(8L, 2L))
    expected1[3:8, ] <- x[1:6, 1:2]
    expect_equal(arr$read(), expected1)

    # now shift BOTH dimensions' low end at once: general fallback ordering,
    # not the single-dimension LFS shortcut
    arr$resize(low = c(2L, 2L))
    expect_equal(arr$shape, c(10L, 4L))
    expected2 <- array(NA_integer_, c(10L, 4L))
    expected2[3:10, 3:4] <- expected1
    expect_equal(arr$read(), expected2)
  }

  run_on_stores(tests)
})
