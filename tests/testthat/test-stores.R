# Store-level tests: the key-value interface of the memory and local stores,
# store properties, and node path helpers.

stores <- list(
  memory = function() zarr_memorystore$new(),
  local  = function() zarr_localstore$new(tempfile(fileext = ".zarr"))
)

# ==== Key-value interface =====================================================

for (st in names(stores)) {
  test_that(paste(st, "store: set(), get() and exists()"), {
    s <- stores[[st]]()
    expect_false(s$exists("a/c.0"))
    expect_null(s$get("a/c.0"))
    s$set("a/c.0", as.raw(0:9))
    expect_true(s$exists("a/c.0"))
    expect_identical(s$get("a/c.0"), as.raw(0:9))
  })

  test_that(paste(st, "store: byte-range reads"), {
    s <- stores[[st]]()
    s$set("k", as.raw(0:9))
    expect_identical(s$get("k", byte_range = 7L), as.raw(7:9))           # offset to end
    expect_identical(s$get("k", byte_range = -3L), as.raw(7:9))          # suffix
    expect_identical(s$get("k", byte_range = c(2L, 5L)), as.raw(2:4))    # exclusive end
    expect_identical(s$get("k", byte_range = c(8L, 100L)), as.raw(8:9))  # clipped end
  })

  test_that(paste(st, "store: set_if_not_exists() does not overwrite"), {
    s <- stores[[st]]()
    s$set_if_not_exists("d/k", as.raw(1:3))
    s$set_if_not_exists("d/k", as.raw(4:6))
    expect_identical(s$get("d/k"), as.raw(1:3))
  })
}

# ==== Hierarchy-level operations ==============================================

for (st in names(stores)) {
  test_that(paste(st, "store: listing groups and arrays"), {
    z <- zarr$new(stores[[st]]())
    zarr_group$new(name = "", parent = z)
    z$add_group("/", "g1")
    z$add_group("/g1", "g11")
    def <- define_array("int32", 4L); def$chunk_shape <- 2L
    z$add_array("/g1", "arr", def)$write(1:4)
    s <- z$store

    expect_setequal(s$list_dir(""), "g1")
    expect_setequal(s$list_dir("g1/"), c("g11", "arr"))
    lp <- s$list_prefix("g1/")
    expect_true(any(grepl("g11", lp)))
    expect_true(any(grepl("arr", lp)))
  })

  test_that(paste(st, "store: delete_array() and delete_group()"), {
    z <- zarr$new(stores[[st]]())
    zarr_group$new(name = "", parent = z)
    z$add_group("/", "g1")
    z$add_group("/g1", "g11")
    z$add_array("/g1", "arr", define_array("int32", 4L))$write(1:4)

    z$delete_array("/g1/arr")
    expect_null(z[["/g1/arr"]])
    expect_false("arr" %in% z$store$list_dir("g1/"))

    z$delete_group("/g1", recursive = TRUE)
    expect_null(z[["/g1"]])
    expect_equal(z$groups, "/")
  })

  test_that(paste(st, "store: deleting a single-array store leaves it uninitialised"), {
    z <- zarr$new(stores[[st]]())
    zarr_array$new(name = "", metadata = define_array("int32", 4L)$metadata(), parent = z)
    z$root$write(1:4)
    z$delete_array("/")
    expect_null(z$root)
  })
}

test_that("memory store: clear() and keys", {
  z <- as_zarr(1:10)
  s <- z$store
  expect_true(length(s$keys) > 0L)
  expect_true(s$clear())
  expect_length(s$keys, 0L)
})

test_that("local store: clear() resets to an empty store", {
  fn <- tempfile(fileext = ".zarr")
  z <- create_zarr(fn)
  z$add_group("/", "g1")
  expect_true(z$store$clear())
  expect_equal(list.files(fn), character())
})

test_that("local store: read-only store refuses to clear or erase", {
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_group("/", "g1")
  s <- zarr_localstore$new(fn, read_only = TRUE)
  expect_true(s$read_only)
  expect_false(s$clear())
  expect_false(s$erase("g1/zarr.json"))
  expect_false(s$erase_prefix("g1/"))
  expect_true(dir.exists(file.path(fn, "g1")))
})

test_that("open_zarr() errors on a local location that does not exist", {
  fn <- tempfile(fileext = ".zarr")
  expect_error(open_zarr(fn), "No Zarr store at location")
  expect_error(open_zarr(path_to_uri(fn)), "No Zarr store at location")
  expect_error(open_zarr(fn, protocol = "local"), "No Zarr store at location")
  expect_false(dir.exists(fn))
})

test_that("open_zarr() errors on a directory that is not a Zarr store", {
  fn <- tempfile()
  dir.create(fn)
  expect_error(open_zarr(fn), "No Zarr store at the root location")
})

# ==== Store properties ========================================================

test_that("store properties", {
  m <- zarr_memorystore$new()
  expect_equal(m$friendlyClassName, "memory store")
  expect_equal(m$separator, ".")
  expect_equal(m$version, 3L)
  expect_false(m$read_only)
  expect_type(m$supports_deletes, "logical")
  expect_type(m$supports_listing, "logical")
  expect_type(m$supports_writes, "logical")
  expect_type(m$supports_consolidated_metadata, "logical")
  expect_false(m$supports_partial_writes)

  fn <- tempfile(fileext = ".zarr")
  l <- zarr_localstore$new(fn)
  expect_equal(l$friendlyClassName, "Local file system store")
  expect_match(l$uri, "^file:///")
  expect_equal(normalizePath(uri_to_path(l$uri), winslash = "/"), normalizePath(fn, winslash = "/"))
  expect_equal(l$separator, ".")
})

test_that("local store opens from a file URI", {
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_group("/", "g1")
  expect_equal(open_zarr(path_to_uri(fn))$groups, c("/", "/g1"))
})

test_that("zarr object accessors", {
  z <- create_zarr()
  expect_equal(z$version, 3L)
  expect_null(z$domain)
  expect_s3_class(z$store, "zarr_memorystore")
})

# ==== Node paths ==============================================================

test_that("relative_path() between nodes", {
  z <- create_zarr()
  z$add_group("/", "a")
  z$add_group("/a", "b")
  z$add_group("/", "c")
  b <- z[["/a/b"]]
  expect_equal(b$relative_path("/c"), "../../c")
  expect_equal(b$relative_path(z[["/a"]]), "..")
  expect_equal(z[["/a"]]$relative_path("/a/b"), "b")
  expect_equal(b$relative_path("/a/b"), ".")
  expect_equal(b$relative_path("/"), ".")
  expect_error(b$relative_path("/a/../c"), "segments must be valid names")
})

test_that("absolute_path() from a node", {
  z <- create_zarr()
  z$add_group("/", "a")
  z$add_group("/a", "b")
  b <- z[["/a/b"]]
  expect_equal(b$absolute_path("../../c"), "/c")
  expect_equal(b$absolute_path("./d"), "/a/b/d")
  expect_equal(b$absolute_path("../.."), "/")
})

test_that("walk_path() errors beyond the root or on a missing child", {
  z <- create_zarr()
  z$add_group("/", "a")
  expect_error(z[["/a"]]$walk_path(c("..", "..")), "beyond the root node")
  expect_error(z[["/a"]]$walk_path("nope"), "non-existent child node")
})

test_that("node accessors: zarr, parent, metadata, dirty", {
  z <- create_zarr()
  z$add_group("/", "a")
  a <- z[["/a"]]
  expect_identical(a$zarr, z)
  expect_identical(z$root$zarr, z)
  expect_identical(a$parent, z$root)
  expect_false(a$dirty)
  a$set_attribute("x", 1)
  expect_true(a$dirty)
  a$dirty <- FALSE
  expect_false(a$dirty)
  meta <- a$metadata
  meta$attributes <- list(y = 2)
  a$metadata <- meta
  expect_true(a$dirty)
  expect_equal(a$attributes, list(y = 2))
})

test_that("get_node() returns NULL for paths that do not resolve", {
  z <- create_zarr()
  z$add_group("/", "a")
  expect_null(z$get_node("/nope"))
  expect_null(z[["/a/nope"]])
  expect_null(z$get_node("/.."))
  expect_null(z[["/a"]]$get_node("nope"))
  expect_null(z[["/a"]]$get_node("../../x"))
  expect_identical(z[["/a"]]$get_node(".."), z$root)
})
