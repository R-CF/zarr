# Tests for the internal helpers in utils.R.

# ==== .protocol() =============================================================

test_that(".protocol() recognizes S3 locations", {
  expect_equal(.protocol("s3://bucket/prefix"), "s3")
  expect_equal(.protocol("S3://bucket"), "s3")
  expect_equal(.protocol("https://bucket.s3.eu-west-1.amazonaws.com/store.zarr"), "s3")
  expect_equal(.protocol("https://s3.amazonaws.com/bucket/store.zarr"), "s3")
})

test_that(".protocol() recognizes HTTP and local locations", {
  expect_equal(.protocol("https://example.org/store.zarr"), "http")
  expect_equal(.protocol("http://localhost:8080/store.zarr"), "http")
  expect_equal(.protocol("/data/store.zarr"), "local")
  expect_equal(.protocol("store.zarr"), "local")
})

# ==== .parse_s3_location() ====================================================

test_that(".parse_s3_location() parses the s3:// scheme", {
  expect_equal(.parse_s3_location("s3://bucket/a/b/store.zarr"),
               list(bucket = "bucket", prefix = "a/b/store.zarr", region = NULL, endpoint = NULL))
  expect_equal(.parse_s3_location("s3://bucket"),
               list(bucket = "bucket", prefix = "", region = NULL, endpoint = NULL))
})

test_that(".parse_s3_location() parses AWS path-style URLs", {
  expect_equal(.parse_s3_location("https://s3.eu-west-1.amazonaws.com/bucket/store.zarr"),
               list(bucket = "bucket", prefix = "store.zarr", region = "eu-west-1", endpoint = NULL))
  # Legacy global endpoint: no region
  expect_equal(.parse_s3_location("https://s3.amazonaws.com/bucket"),
               list(bucket = "bucket", prefix = "", region = NULL, endpoint = NULL))
})

test_that(".parse_s3_location() parses AWS virtual-hosted URLs", {
  expect_equal(.parse_s3_location("https://bucket.s3.us-west-2.amazonaws.com/a/store.zarr"),
               list(bucket = "bucket", prefix = "a/store.zarr", region = "us-west-2", endpoint = NULL))
  expect_equal(.parse_s3_location("https://bucket.s3.amazonaws.com/store.zarr"),
               list(bucket = "bucket", prefix = "store.zarr", region = NULL, endpoint = NULL))
})

test_that(".parse_s3_location() treats other hosts as path-style S3-compatible endpoints", {
  expect_equal(.parse_s3_location("https://minio.example.org:9000/bucket/a/store.zarr"),
               list(bucket = "bucket", prefix = "a/store.zarr", region = NULL,
                    endpoint = "https://minio.example.org:9000"))
  expect_equal(.parse_s3_location("http://localhost/bucket")$prefix, "")
})

# ==== zarr_options() ==========================================================

test_that("zarr_options() lists and retrieves options", {
  opts <- zarr_options()
  expect_type(opts, "list")
  expect_true(all(c("chunk_length", "eps") %in% names(opts)))
  expect_identical(zarr_options("chunk_length"), opts$chunk_length)
})

test_that("zarr_options() sets numeric options and ignores invalid values", {
  old <- zarr_options()
  on.exit({
    zarr_options("chunk_length", old$chunk_length)
    zarr_options("chunk_cache_bytes", old$chunk_cache_bytes)
    zarr_options("min_compress", old$min_compress)
    zarr_options("eps", old$eps)
  })

  zarr_options("chunk_length", 250.7)
  expect_identical(zarr_options("chunk_length"), 250L)
  zarr_options("chunk_cache_bytes", 1e6)
  expect_identical(zarr_options("chunk_cache_bytes"), 1e6)
  zarr_options("min_compress", 10)
  expect_identical(zarr_options("min_compress"), 10L)
  zarr_options("eps", 1e-6)
  expect_identical(zarr_options("eps"), 1e-6)

  zarr_options("chunk_length", "lots")
  expect_identical(zarr_options("chunk_length"), 250L)
})

# ==== Small helpers ===========================================================

test_that(".size_string() picks the right unit", {
  expect_equal(.size_string(512), "512 Bytes")
  expect_equal(.size_string(2048), "2 KB")
  expect_equal(.size_string(1.5 * 1048576), "1.5 MB")
  expect_equal(.size_string(3 * 1073741824), "3 GB")
})

test_that(".slim.data.frame() collapses and truncates entries", {
  df <- .slim.data.frame(list(a = 1:3, b = strrep("x", 60)), width = 20L)
  expect_equal(df$name, c("a", "b"))
  expect_equal(df$value, c("1, 2, 3", paste0(strrep("x", 17), "...")))
  expect_equal(nrow(.slim.data.frame(list())), 0L)
})

test_that("auto_chunk() splits dimensions into near-equal chunks", {
  expect_equal(auto_chunk(c(250L, 50L), 100L), c(84L, 50L))
  expect_equal(auto_chunk(1000L, 1000L), 1000L)
})

test_that(".near() uses a tolerance relative to each element, not the vector maximum", {
  expect_equal(.near(c(0.5, 1e10, 1e10 + 1), 0), c(FALSE, FALSE, FALSE))
  expect_equal(.near(c(1, 1e10), c(1 + 1e-12, 1e10 * (1 + 1e-10))), c(TRUE, TRUE))
})
