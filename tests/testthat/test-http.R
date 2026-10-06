# Tests for the HTTP store, against a local web server that serves a directory
# and honours "Range" requests, as static file servers in production do.

skip_if_not_installed("webfakes")
skip_if_not_installed("curl")

# Start a server for directory `root` for the duration of the calling test.
serve_dir <- function(root, .local_envir = parent.frame()) {
  app <- webfakes::new_app()
  app$locals$root <- root
  app$get(webfakes::new_regexp("^/(?<path>.*)$"), function(req, res) {
    fn <- file.path(req$app$locals$root, req$params$path)
    if (!file.exists(fn) || dir.exists(fn))
      return(res$send_status(404L))
    data <- readBin(fn, "raw", file.size(fn))
    rng <- req$get_header("Range")
    if (!is.null(rng)) {
      m <- regmatches(rng, regexec("^bytes=(\\d*)-(\\d*)$", rng))[[1L]]
      n <- length(data)
      start <- if (nzchar(m[2L])) as.integer(m[2L]) else n - as.integer(m[3L])
      end   <- if (nzchar(m[2L]) && nzchar(m[3L])) min(as.integer(m[3L]), n - 1L) else n - 1L
      res$set_status(206L)
      data <- data[(start + 1L):(end + 1L)]
    }
    res$set_type("application/octet-stream")
    res$send(data)
  })
  webfakes::local_app_process(app, .local_envir = .local_envir)
}

# ==== Zarr v3 =================================================================

test_that("HTTP store reads a v3 single-array store", {
  fn <- tempfile(fileext = ".zarr")
  x <- matrix(as.numeric(1:200), 10L, 20L)
  as_zarr(x, location = fn)
  srv <- serve_dir(fn)

  z <- open_zarr(srv$url())
  expect_s3_class(z$store, "zarr_httpstore")
  expect_equal(z$store$friendlyClassName, "HTTP store")
  expect_equal(z$store$root, sub("/$", "", srv$url()))
  expect_equal(z$store$uri, z$store$root)
  expect_true(z$store$read_only)
  expect_equal(z$root$read(), x)
  expect_equal(z$root[3:4, 5:6], x[3:4, 5:6])
})

test_that("HTTP store byte-range requests", {
  root <- tempfile()
  dir.create(root)
  writeBin(as.raw(0:9), file.path(root, "blob"))
  writeLines('{"zarr_format": 3, "node_type": "group"}', file.path(root, "zarr.json"))
  srv <- serve_dir(root)

  s <- zarr_httpstore$new(srv$url())
  expect_identical(s$get("blob"), as.raw(0:9))
  expect_identical(s$get("blob", byte_range = 7L), as.raw(7:9))
  expect_identical(s$get("blob", byte_range = -3L), as.raw(7:9))
  expect_identical(s$get("blob", byte_range = c(2L, 5L)), as.raw(2:4))
  expect_null(s$get("missing"))
})

test_that("HTTP store reads a sharded array with byte-range requests", {
  srv <- serve_dir(test_path("testdata/sharded_test.zarr"))
  local <- open_zarr(test_path("testdata/sharded_test.zarr"))
  for (nm in c("float1d", "float2d", "int3d")) {
    z <- open_zarr(paste0(srv$url(), nm))
    expect_equal(z$root$read(), local[[paste0("/", nm)]]$read(), info = nm)
  }
})

test_that("HTTP store is read-only", {
  root <- tempfile()
  dir.create(root)
  writeLines('{"zarr_format": 3, "node_type": "group"}', file.path(root, "zarr.json"))
  srv <- serve_dir(root)
  s <- zarr_httpstore$new(srv$url())
  expect_false(s$clear())
  expect_false(s$erase("zarr.json"))
  expect_false(s$erase_prefix(""))
  expect_invisible(s$set("k", as.raw(1)))
  expect_invisible(s$set_if_not_exists("k", as.raw(1)))
  expect_invisible(s$set_metadata("", list()))
  expect_null(s$get("k"))
  expect_true(s$exists("/"))
  expect_false(s$exists("k"))
  expect_equal(s$list_dir(""), character(0))
  expect_equal(s$list_prefix(""), character(0))
  expect_true(s$is_group("/"))
})

test_that("HTTP store errors when there is no Zarr store at the URL", {
  root <- tempfile()
  dir.create(root)
  srv <- serve_dir(root)
  expect_error(zarr_httpstore$new(srv$url()), "No compatible store found")
})

# ==== Zarr v2 =================================================================

# A v2 hierarchy: root group with attributes, sub-group "grp" and int32 array
# "grp/temp" (2 x 3, C order, no compressor).
make_v2_http_store <- function(consolidated) {
  root <- tempfile(fileext = ".zarr")
  dir.create(file.path(root, "grp", "temp"), recursive = TRUE)
  zgroup <- '{"zarr_format": 2}'
  zarray <- '{"zarr_format": 2, "shape": [2, 3], "chunks": [2, 3], "dtype": "<i4",
    "compressor": null, "fill_value": 0, "filters": null, "order": "C"}'
  writeLines(zgroup, file.path(root, ".zgroup"))
  writeLines('{"title": "v2 over http"}', file.path(root, ".zattrs"))
  writeLines(zgroup, file.path(root, "grp", ".zgroup"))
  writeLines(zarray, file.path(root, "grp", "temp", ".zarray"))
  writeLines('{"units": "K"}', file.path(root, "grp", "temp", ".zattrs"))
  writeBin(1:6, file.path(root, "grp", "temp", "0.0"), size = 4L, endian = "little")
  if (consolidated)
    writeLines(sprintf('{"zarr_consolidated_format": 1, "metadata": {
      ".zgroup": %s, ".zattrs": {"title": "v2 over http"},
      "grp/.zgroup": %s,
      "grp/temp/.zarray": %s, "grp/temp/.zattrs": {"units": "K"}}}', zgroup, zgroup, zarray),
      file.path(root, ".zmetadata"))
  root
}

test_that("HTTP store reads a v2 store with consolidated metadata", {
  srv <- serve_dir(make_v2_http_store(consolidated = TRUE))
  z <- open_zarr(srv$url())
  expect_equal(z$version, 2L)
  expect_equal(z$groups, c("/", "/grp"))
  expect_equal(z$root$attributes$title, "v2 over http")
  arr <- z[["/grp/temp"]]
  expect_equal(arr$attributes$units, "K")
  expect_equal(arr$read(), matrix(1:6, 2L, 3L, byrow = TRUE))
})

test_that("HTTP store with consolidated metadata lists nodes and keys", {
  srv <- serve_dir(make_v2_http_store(consolidated = TRUE))
  s <- zarr_httpstore$new(srv$url())
  expect_equal(s$list_dir(""), "grp")
  expect_equal(s$list_dir("grp/"), "temp")
  expect_true("/grp/temp/.zarray" %in% s$list_prefix("grp/"))
  expect_true(s$exists("grp/temp"))
  expect_true(s$is_group("/grp"))
  expect_false(s$is_group("/grp/temp"))
  expect_null(s$get_metadata("nope/"))
})

test_that("HTTP store reads a v2 single-array store without consolidated metadata", {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  writeLines('{"zarr_format": 2, "shape": [4], "chunks": [4], "dtype": "<f8",
    "compressor": null, "fill_value": null, "filters": null, "order": "C"}', file.path(root, ".zarray"))
  writeLines('{"units": "m"}', file.path(root, ".zattrs"))
  writeBin(c(0.5, 1.5, 2.5, 3.5), file.path(root, "0"), size = 8L, endian = "little")
  srv <- serve_dir(root)

  z <- open_zarr(srv$url())
  expect_equal(z$root$read(), c(0.5, 1.5, 2.5, 3.5))
  expect_equal(z$root$attributes$units, "m")
})
