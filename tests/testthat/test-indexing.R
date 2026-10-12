x <- array(1:120, c(4, 5, 6))

new_arr <- function(data = x) as_zarr(data)[['/']]

# --- [ ----------------------------------------------------------------------

test_that("[ with all indices empty returns the full array", {
  arr <- new_arr()
  expect_identical(arr[, , ], x)
})

test_that("[] returns the full array", {
  arr <- new_arr()
  expect_identical(arr[], x)
})

test_that("[ returns a contiguous block", {
  arr <- new_arr()
  expect_identical(arr[2:3, 1:4, 5:6], x[2:3, 1:4, 5:6])
})

test_that("[ drops degenerate dimensions by default", {
  arr <- new_arr()
  expect_identical(arr[2, , 3], x[2, , 3])
  expect_identical(arr[2, 3, 4], x[2, 3, 4])
})

test_that("[ keeps degenerate dimensions with drop = FALSE", {
  arr <- new_arr()
  expect_identical(arr[2, , 3, drop = FALSE], x[2, , 3, drop = FALSE])
})

test_that("[ accepts negative and logical indices", {
  arr <- new_arr()
  expect_identical(arr[-1, , ], x[-1, , ])
  expect_identical(arr[, c(FALSE, TRUE, TRUE, FALSE, FALSE), ], x[, 2:3, ])
})

test_that("[ evaluates indices in the caller's frame", {
  arr <- new_arr()
  f <- function(a, i) a[i, 1, 1]
  expect_identical(f(arr, 2:4), x[2:4, 1, 1])
})

test_that("[ errors on a wrong number of indices", {
  arr <- new_arr()
  expect_error(arr[1, 1])
})

test_that("[ errors on non-consecutive indices", {
  arr <- new_arr()
  expect_error(arr[c(1, 3), 1, 1], "consecutive")
})

test_that("[ errors on out-of-bounds indices", {
  arr <- new_arr()
  expect_error(arr[1:5, 1, 1], "out of bounds")
})

# --- [<- --------------------------------------------------------------------

test_that("[<- keeps the identity of the zarr_array", {
  arr <- new_arr()
  a0 <- arr
  arr[1, 1, 1] <- 999L
  expect_identical(arr, a0)
})

test_that("[<- writes a block and leaves the rest untouched", {
  arr <- new_arr()
  v <- array(-(1:24), c(2, 3, 4))
  arr[2:3, 1:3, 3:6] <- v
  y <- x
  y[2:3, 1:3, 3:6] <- v
  expect_identical(arr[, , ], y)
})

test_that("[<- with an empty index writes the full extent", {
  arr <- new_arr()
  v <- -(1:5)
  arr[2, , 3] <- v
  y <- x
  y[2, , 3] <- v
  expect_identical(arr[, , ], y)
})

test_that("[<- broadcasts a single value over the selection", {
  arr <- new_arr()
  arr[1:2, 1:2, 1] <- 7L
  expect_true(all(arr[1:2, 1:2, 1] == 7L))
})

test_that("[<- round-trips NA", {
  arr <- new_arr()
  arr[, 5, 1] <- NA_integer_
  expect_true(all(is.na(arr[, 5, 1])))
  expect_false(anyNA(arr[, 1:4, ]))
})

test_that("[<- evaluates indices in the caller's frame", {
  arr <- new_arr()
  f <- function(a, i, v) { a[i, 1, 1] <- v; invisible(NULL) }
  f(arr, 2:3, c(-1L, -2L))
  expect_identical(arr[2:3, 1, 1], c(-1L, -2L))
})

test_that("[<- errors on a wrong number of indices", {
  arr <- new_arr()
  expect_error(arr[1, 1] <- 1L, "number of selection indices")
})

test_that("[<- errors on non-consecutive indices", {
  arr <- new_arr()
  expect_error(arr[c(1, 3), 1, 1] <- 0L, "consecutive")
  expect_identical(arr[, , ], x)
})

test_that("[<- errors on data of the wrong type", {
  arr <- new_arr()
  expect_error(arr[1, 1, 1] <- 1.5, "different type")
})

test_that("[<- errors on a read-only store", {
  fn <- tempfile(fileext = '.zarr')
  on.exit(unlink(fn, recursive = TRUE), add = TRUE)
  as_zarr(x, location = fn)
  arr <- open_zarr(fn, read_only = TRUE)[['/']]
  expect_error(arr[1, 1, 1] <- 1L, "read-only")
})
