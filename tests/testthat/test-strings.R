# Tests for string-type (variable-length UTF-8) Zarr arrays
#
# The test store contains:
#
#   /scalar1d   shape=(1)    dtype=string   fill=""        1 chunk
#   /names1d    shape=(6)    dtype=string   fill=""        1 chunk
#   /grid2d     shape=(3,4)  dtype=string   fill="N/A"     chunks=(2,2)
#   /unicode1d  shape=(5)    dtype=string   fill=""        1 chunk
#   /sparse1d   shape=(10)   dtype=string   fill="missing" 2 chunks
#                (chunk 0 written, chunk 1 absent → all fill values)
#
# The store can be generated with the helper script
# tests/testthat/helper-string-arrays.R.

# ---------------------------------------------------------------------------
# dtype detection and metadata
# ---------------------------------------------------------------------------

test_that("string dtype is detected from array metadata", {
  arr <- z_strings[["/names1d"]]
  expect_equal(arr$data_type$data_type, "string")
})

test_that("string fill_value is stored as character", {
  expect_equal(z_strings[["/names1d"]]$data_type$fill_value, "")
  expect_equal(z_strings[["/grid2d"]]$data_type$fill_value,  "N/A")
  expect_equal(z_strings[["/sparse1d"]]$data_type$fill_value, "missing")
})

test_that("string array shape and chunk layout are parsed correctly", {
  arr <- z_strings[["/grid2d"]]
  expect_equal(arr$shape,       c(3L, 4L))
  expect_equal(arr$chunking$chunk_shape, c(2L, 2L))
})

# ---------------------------------------------------------------------------
# Return type
# ---------------------------------------------------------------------------

test_that("reading a string array returns a character vector", {
  arr <- z_strings[["/names1d"]]

  result <- arr[]
  expect_type(result, "character")
})

test_that("reading a 2D string array returns a character matrix", {
  arr <- z_strings[["/grid2d"]]

  result <- arr[]
  expect_type(result, "character")
  expect_equal(dim(result), c(3L, 4L))
})

# ---------------------------------------------------------------------------
# Single-element reads
# ---------------------------------------------------------------------------

test_that("single element read returns the correct string scalar", {
  arr <- z_strings[["/names1d"]]

  # names1d contains c("alpha", "beta", "gamma", "delta", "epsilon", "zeta")
  expect_equal(arr[1], "alpha")
  expect_equal(arr[3], "gamma")
  expect_equal(arr[6], "zeta")
})

test_that("single element read from a 2D string array is correct", {
  arr <- z_strings[["/grid2d"]]

  expect_equal(arr[1, 1], "r1c1")
  expect_equal(arr[2, 3], "r2c3")
  expect_equal(arr[3, 4], "r3c4")
})

# ---------------------------------------------------------------------------
# Slice reads
# ---------------------------------------------------------------------------

test_that("contiguous slice within a single chunk is correct", {
  arr <- z_strings[["/names1d"]]

  result <- arr[2:4]
  expect_equal(result, c("beta", "gamma", "delta"))
})

test_that("slice crossing a chunk boundary is correct", {
  arr <- z_strings[["/grid2d"]]

  # chunk boundary falls at row 2 and col 2
  result <- arr[1:3, 2:4]
  expect_equal(dim(result), c(3L, 3L))
  expect_equal(result[1, 1], "r1c2")
  expect_equal(result[2, 3], "r2c4")
  expect_equal(result[3, 2], "r3c3")
})

test_that("full array read matches expected content", {
  arr <- z_strings[["/names1d"]]

  expected <- c("alpha", "beta", "gamma", "delta", "epsilon", "zeta")
  expect_equal(arr[], expected)
})

# ---------------------------------------------------------------------------
# Fill value / absent chunks
# ---------------------------------------------------------------------------

test_that("elements in an absent chunk return the fill value", {
  arr <- z_strings[["/sparse1d"]]

  # chunk 0 (indices 1–5) is written; chunk 1 (indices 6–10) is absent
  result <- arr[6:10]
  expect_equal(result, rep("missing", 5L))
})

test_that("mixed read across present and absent chunks is correct", {
  arr <- z_strings[["/sparse1d"]]

  # sparse1d chunk 0 contains c("a","b","c","d","e")
  result <- arr[4:7]
  expect_equal(result, c("d", "e", "missing", "missing"))
})

# ---------------------------------------------------------------------------
# Unicode and special characters
# ---------------------------------------------------------------------------

test_that("UTF-8 strings with multi-byte characters round-trip correctly", {
  arr <- z_strings[["/unicode1d"]]

  # unicode1d contains strings with accented, CJK, emoji, and RTL characters
  result <- arr[]
  expect_equal(result[1], "\u00e9l\u00e8ve")        # "élève"
  expect_equal(result[2], "\u4e2d\u6587")            # "中文"
  expect_equal(result[3], "\U0001f331")              # 🌱
  expect_equal(result[4], "\u0645\u0631\u062d\u0628\u0627") # "مرحبا"
  expect_equal(result[5], "caf\u00e9")               # "café"
})

test_that("empty string elements are returned as empty character strings", {
  arr <- z_strings[["/names1d"]]

  # scalar1d contains a single character string
  result <- z_strings[["/scalar1d"]][]
  expect_equal(result, "x")
  expect_equal(nchar(result), 1L)
})

# ---------------------------------------------------------------------------
# fill_value setting on array_builder (unit tests, no store needed)
# ---------------------------------------------------------------------------

test_that("array_builder accepts a character fill_value for string dtype", {
  b <- array_builder$new()
  b$data_type <- "string"
  b$fill_value <- "N/A"

  expect_equal(b$fill_value, "N/A")
})

test_that("array_builder accepts an empty string fill_value for string dtype", {
  b <- array_builder$new()
  b$data_type <- "string"
  b$fill_value <- ""

  expect_equal(b$fill_value, "")
})

test_that("array_builder rejects a numeric fill_value for string dtype", {
  b <- array_builder$new()
  b$data_type <- "string"

  expect_error(b$fill_value <- 0L, regexp = "fill_value")
})
