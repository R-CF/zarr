# Tests for the RFC 8089 / RFC 3986 helpers in uri.R. The Windows branches
# (drive letters, UNC paths) are only reachable on Windows.

# ==== path_to_uri() ===========================================================

test_that("path_to_uri() encodes an absolute path", {
  skip_on_os("windows")
  expect_equal(path_to_uri("/data/stores/a.zarr"), "file:///data/stores/a.zarr")
})

test_that("path_to_uri() percent-encodes reserved and non-ASCII characters", {
  skip_on_os("windows")
  expect_equal(path_to_uri("/data/my store/a#1.zarr"), "file:///data/my%20store/a%231.zarr")
  expect_equal(path_to_uri("/data/µs"), "file:///data/%C2%B5s")
})

test_that("path_to_uri() keeps a relative path relative", {
  expect_equal(path_to_uri("stores/a b.zarr"), "file:stores/a%20b.zarr")
  expect_equal(path_to_uri("stores//a.zarr"), "file:stores/a.zarr")
})

test_that("path_to_uri() expands the home directory", {
  skip_on_os("windows")
  expect_equal(path_to_uri("~/a.zarr"), path_to_uri(file.path(path.expand("~"), "a.zarr")))
})

# ==== uri_to_path() ===========================================================

test_that("uri_to_path() passes through anything that is not a file URI", {
  expect_equal(uri_to_path("/data/a.zarr"), "/data/a.zarr")
  expect_equal(uri_to_path("https://example.org/a.zarr"), "https://example.org/a.zarr")
})

test_that("uri_to_path() decodes absolute file URIs", {
  skip_on_os("windows")
  expect_equal(uri_to_path("file:///data/my%20store/a%231.zarr"), "/data/my store/a#1.zarr")
  expect_equal(uri_to_path("file:/data/a.zarr"), "/data/a.zarr")
})

test_that("uri_to_path() decodes relative file URIs", {
  expect_equal(uri_to_path("file:stores/a%20b.zarr"), file.path("stores", "a b.zarr"))
})

test_that("path_to_uri() and uri_to_path() round-trip", {
  skip_on_os("windows")
  for (p in c("/data/a.zarr", "/tmp/my store/µs/東京.zarr", "/a/b#c/d?e"))
    expect_equal(uri_to_path(path_to_uri(p)), p)
})

# ==== is_valid_uri() ==========================================================

test_that("is_valid_uri() accepts well-formed URIs", {
  valid <- c("https://example.org/a.zarr",
             "https://user:pw@example.org:8080/a/b?x=1&y=2#frag",
             "http://192.168.1.1/data",
             "http://[2001:db8::1]/data",
             "s3://bucket/prefix/store.zarr",
             "file:///data/my%20store",
             "urn:isbn:0451450523",
             "mailto:someone@example.org")
  for (u in valid) expect_true(is_valid_uri(u), info = u)
})

test_that("is_valid_uri() rejects input that is not a single string", {
  expect_false(is_valid_uri(1))
  expect_false(is_valid_uri(c("https://a.org", "https://b.org")))
  expect_false(is_valid_uri(NA))
})

test_that("is_valid_uri() requires a valid scheme", {
  expect_false(is_valid_uri("/relative/path"))
  expect_false(is_valid_uri("1http://example.org"))
  expect_false(is_valid_uri("ht_tp://example.org"))
})

test_that("is_valid_uri() rejects invalid authorities", {
  expect_false(is_valid_uri("https://us er@example.org/"))
  expect_false(is_valid_uri("https://exa mple.org/"))
  expect_false(is_valid_uri("https://exa%zzmple.org/"))
})

test_that("is_valid_uri() rejects invalid paths, queries and fragments", {
  expect_false(is_valid_uri("https://example.org/a b"))
  expect_false(is_valid_uri("https://example.org/a?x=1 2"))
  expect_false(is_valid_uri("https://example.org/a#frag ment"))
})
