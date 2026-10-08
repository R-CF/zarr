# Tests for copying Zarr hierarchies: the raw chunk I/O of the chunking classes,
# and the internal copy_to() methods of zarr_array and zarr_group

x <- array(1:70, c(10L, 7L))

# A 10 x 7 int32 array in 4 x 3 chunks: a 3 x 3 grid with partial edge chunks
new_def <- function() {
  def <- define_array("int32", c(10L, 7L))
  def$chunk_shape <- c(4L, 3L)
  def
}

# Root group and sub-group "g", both with an attribute, and array "/g/a"
new_source <- function() {
  z <- create_zarr()
  z$root$set_attribute("title", "source")
  g <- z$add_group("/", "g")
  g$set_attribute("kind", "sub")
  g$save()
  z$add_array("/g", "a", new_def())
  z
}

stored_bytes <- function(arr)
  lapply(stats::setNames(nm = arr$chunking$chunk_keys()), arr$chunking$read_raw)

# ==== chunk_keys() ============================================================

test_that("chunk_keys() covers the full chunk grid", {
  keys <- new_source()[["/g/a"]]$chunking$chunk_keys()
  expect_length(keys, 9L)
  expect_setequal(keys, paste0("c.", outer(0:2, 0:2, paste, sep = ".")))
})

test_that("chunk_keys() gives the scalar key for a scalar array", {
  arr <- create_zarr()$add_array("/", "s", define_array("int32", integer(0)))
  expect_equal(arr$chunking$chunk_keys(), "c")
})

# ==== read_raw() / write_raw() ================================================

test_that("read_raw() returns NULL for an absent chunk", {
  arr <- new_source()[["/g/a"]]
  expect_null(arr$chunking$read_raw("c.0.0"))
})

test_that("read_raw() flushes pending edits first", {
  arr <- new_source()[["/g/a"]]
  arr$write(x, flush = FALSE)
  expect_type(arr$chunking$read_raw("c.0.0"), "raw")
})

test_that("write_raw() drops a cached chunk", {
  src <- new_source()[["/g/a"]]
  src$write(x)
  dst <- create_zarr()$add_array("/", "a", new_def())
  expect_true(all(is.na(dst[1:4, 1:3])))   # caches a fill-value buffer
  dst$chunking$write_raw("c.0.0", src$chunking$read_raw("c.0.0"))
  expect_equal(dst[1:4, 1:3], x[1:4, 1:3])
})

# ==== zarr_array$copy_to() ====================================================

test_that("array copy_to() returns dest", {
  src <- new_source()[["/g/a"]]
  dz <- create_zarr()
  expect_identical(src$copy_to(dz$root, list()), dz$root)
})

test_that("array copy_to() produces byte-identical chunks", {
  src <- new_source()[["/g/a"]]
  src$write(x)
  dz <- create_zarr()
  src$copy_to(dz$root, list())
  expect_identical(stored_bytes(dz[["/a"]]), stored_bytes(src))
  expect_equal(dz[["/a"]][], x)
})

test_that("array copy_to() leaves absent chunks absent", {
  src <- new_source()[["/g/a"]]
  src$write(x[1:4, 1:3], list(c(1L, 4L), c(1L, 3L)))
  dz <- create_zarr()
  src$copy_to(dz$root, list())
  expect_equal(sum(!sapply(stored_bytes(dz[["/a"]]), is.null)), 1L)
})

test_that("array copy_to() includes unflushed edits", {
  src <- new_source()[["/g/a"]]
  src$write(x, flush = FALSE)
  dz <- create_zarr()
  src$copy_to(dz$root, list())
  expect_equal(dz[["/a"]][], x)
})

test_that("array copy_to() keeps the array attributes", {
  src <- new_source()[["/g/a"]]
  src$set_attribute("units", "K")
  dz <- create_zarr()
  src$copy_to(dz$root, list())
  expect_equal(dz[["/a"]]$attribute("units"), "K")
})

test_that("array copy_to() copies a scalar array", {
  src <- create_zarr()$add_array("/", "s", define_array("int32", integer(0)))
  src$write(42L)
  dz <- create_zarr()
  src$copy_to(dz$root, list())
  expect_equal(dz[["/s"]][], 42L)
})

test_that("array copy_to() copies whole shards of a sharded array", {
  skip_if_not_installed("zlib")    # opening the store needs every codec
  skip_if_not_installed("digest")
  skip_if_not_installed("bit64")
  src <- open_zarr("testdata/sharded_test.zarr")[["/float2d"]]
  dz <- create_zarr()
  src$copy_to(dz$root, list())
  dst <- dz[["/float2d"]]
  expect_s3_class(dst$chunking, "chunk_grid_sharded")
  expect_identical(stored_bytes(dst), stored_bytes(src))
  expect_equal(dst[], src[])
})

# ==== zarr_group$copy_to() ====================================================

test_that("group copy_to() returns dest", {
  dz <- zarr$new()
  expect_identical(new_source()$root$copy_to(dz, list()), dz)
})

test_that("group copy_to() recreates the hierarchy", {
  z <- new_source()
  z$add_group("/g", "empty")
  dz <- zarr$new()
  z$root$copy_to(dz, list())
  expect_equal(dz$groups, z$groups)
  expect_equal(dz$arrays, z$arrays)
})

test_that("group copy_to() copies the array data", {
  z <- new_source()
  z[["/g/a"]]$write(x)
  dz <- zarr$new()
  z$root$copy_to(dz, list())
  expect_identical(stored_bytes(dz[["/g/a"]]), stored_bytes(z[["/g/a"]]))
  expect_equal(dz[["/g/a"]][], x)
})

test_that("group copy_to() persists group attributes", {
  fn <- tempfile(fileext = ".zarr")
  on.exit(unlink(fn, recursive = TRUE))
  new_source()$root$copy_to(zarr$new(fn), list())
  expect_equal(open_zarr(fn)[["/g"]]$attribute("kind"), "sub")
})

test_that("group copy_to() persists root group attributes", {
  fn <- tempfile(fileext = ".zarr")
  on.exit(unlink(fn, recursive = TRUE))
  new_source()$root$copy_to(zarr$new(fn), list())
  expect_equal(open_zarr(fn)$root$attribute("title"), "source")
})

test_that("group copy_to() works from memory to a local store", {
  z <- new_source()
  z[["/g/a"]]$write(x)
  fn <- tempfile(fileext = ".zarr")
  on.exit(unlink(fn, recursive = TRUE))
  z$root$copy_to(zarr$new(fn), list())
  local <- open_zarr(fn)[["/g/a"]]
  expect_identical(stored_bytes(local), stored_bytes(z[["/g/a"]]))
  expect_equal(local[], x)
})

# ==== Single-array stores =====================================================

test_that("a single-array store copies to an empty memory store", {
  src <- as_zarr(x)$root
  dz <- zarr$new()
  src$copy_to(dz, list())
  expect_s3_class(dz$root, "zarr_array")
  expect_equal(dz$root[], x)
})

test_that("a single-array store copies to an empty local store", {
  src <- as_zarr(x)$root
  fn <- tempfile(fileext = ".zarr")
  on.exit(unlink(fn, recursive = TRUE))
  src$copy_to(zarr$new(fn), list())
  local <- open_zarr(fn)
  expect_s3_class(local$root, "zarr_array")
  expect_equal(local$root[], x)
})

# ==== zarr_group$initialize() =================================================

test_that("a group created without metadata has default group metadata", {
  g <- create_zarr()$add_group("/", "g")
  expect_equal(g$metadata$node_type, "group")
  expect_false(g$dirty)
})

test_that("groups opened from a store are not dirty", {
  fn <- tempfile(fileext = ".zarr")
  on.exit(unlink(fn, recursive = TRUE))
  z <- create_zarr(fn)
  z$add_group("/", "g")$set_attribute("kind", "sub")$save()
  expect_false(open_zarr(fn)[["/g"]]$dirty)
})
