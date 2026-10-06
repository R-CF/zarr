# Tests for the S3 store. paws.storage::s3() is mocked with an in-memory fake
# client, so these tests need neither network access nor credentials. The fake
# signals errors the way paws does: an R condition whose message carries the
# S3 error code and HTTP status.

skip_if_not_installed("paws.storage")

# A fake S3 client. Objects live in `objects` keyed by "bucket/key". Listings
# are paginated two entries at a time to exercise continuation tokens. The
# config passed to s3() is kept in `state$config` for inspection.
fake_s3 <- function(state) {
  objects <- state$objects
  full <- function(Bucket, Key) paste0(Bucket, "/", Key)
  not_found <- function(Key) stop("NoSuchKey (HTTP 404). The specified key does not exist: ", Key, call. = FALSE)
  slice <- function(body, range) {
    if (is.null(range)) return(body)
    m <- regmatches(range, regexec("^bytes=(\\d*)-(\\d*)$", range))[[1L]]
    n <- length(body)
    start <- if (nzchar(m[2L])) as.integer(m[2L]) else n - as.integer(m[3L])
    end   <- if (nzchar(m[2L]) && nzchar(m[3L])) min(as.integer(m[3L]), n - 1L) else n - 1L
    body[(start + 1L):(end + 1L)]
  }

  list(
    get_object = function(Bucket, Key, Range = NULL) {
      if (!is.null(state$fail_on) && grepl(state$fail_on, Key))
        stop("InternalError (HTTP 500). We encountered an internal error.", call. = FALSE)
      body <- objects[[full(Bucket, Key)]]
      if (is.null(body)) not_found(Key)
      body <- slice(body, Range)
      list(Body = body, ContentLength = length(body))
    },
    head_object = function(Bucket, Key) {
      body <- objects[[full(Bucket, Key)]]
      if (is.null(body)) stop("NotFound (HTTP 404).", call. = FALSE)
      list(ContentLength = length(body))
    },
    put_object = function(Bucket, Key, Body, IfNoneMatch = NULL) {
      k <- full(Bucket, Key)
      if (identical(IfNoneMatch, "*") && !is.null(objects[[k]]))
        stop("PreconditionFailed (HTTP 412). At least one of the preconditions did not hold.", call. = FALSE)
      objects[[k]] <- Body
      list()
    },
    delete_object = function(Bucket, Key) {
      k <- full(Bucket, Key)
      if (exists(k, objects, inherits = FALSE)) rm(list = k, envir = objects)
      list()
    },
    delete_objects = function(Bucket, Delete) {
      for (o in Delete$Objects) {
        k <- full(Bucket, o$Key)
        if (exists(k, objects, inherits = FALSE)) rm(list = k, envir = objects)
      }
      list()
    },
    copy_object = function(Bucket, Key, CopySource) {
      objects[[full(Bucket, Key)]] <- objects[[CopySource]]
      list()
    },
    list_objects_v2 = function(Bucket, Prefix = "", Delimiter = NULL,
                               ContinuationToken = NULL, MaxKeys = NULL) {
      keys <- sort(sub(paste0("^", Bucket, "/"), "",
                       grep(paste0("^", Bucket, "/"), ls(objects, all.names = TRUE), value = TRUE)))
      keys <- keys[startsWith(keys, Prefix)]
      entries <- if (is.null(Delimiter)) {
        lapply(keys, function(k) list(type = "key", value = k))
      } else {
        rest <- substring(keys, nchar(Prefix) + 1L)
        is_dir <- grepl(Delimiter, rest, fixed = TRUE)
        dirs <- unique(paste0(Prefix, sub(paste0(Delimiter, ".*"), Delimiter, rest[is_dir])))
        c(lapply(dirs, function(d) list(type = "prefix", value = d)),
          lapply(keys[!is_dir], function(k) list(type = "key", value = k)))
      }
      page_size <- MaxKeys %||% 2L
      start <- if (is.null(ContinuationToken)) 1L else as.integer(ContinuationToken)
      page <- entries[seq_len(min(page_size, max(0L, length(entries) - start + 1L))) + start - 1L]
      truncated <- start + page_size <= length(entries)
      list(
        Contents = lapply(Filter(function(e) e$type == "key", page),
                          function(e) list(Key = e$value, Size = length(objects[[full(Bucket, e$value)]]))),
        CommonPrefixes = lapply(Filter(function(e) e$type == "prefix", page),
                                function(e) list(Prefix = e$value)),
        IsTruncated = truncated,
        NextContinuationToken = if (truncated) as.character(start + page_size) else NULL
      )
    }
  )
}

# Mock paws.storage::s3() for the calling test; returns the shared state.
local_fake_s3 <- function(.env = parent.frame()) {
  state <- new.env()
  state$objects <- new.env()
  testthat::local_mocked_bindings(
    s3 = function(config = list(), ...) {
      state$config <- config
      fake_s3(state)
    },
    .package = "paws.storage", .env = .env)
  state
}

# Copy the files of a local store directory into the fake bucket under `prefix`.
upload_dir <- function(state, dir, bucket, prefix) {
  files <- list.files(dir, recursive = TRUE, all.files = TRUE)
  for (f in files)
    state$objects[[paste0(bucket, "/", prefix, f)]] <-
      readBin(file.path(dir, f), "raw", file.size(file.path(dir, f)))
}

new_bucket_store <- function(state, bucket = "bkt", prefix = "data/store.zarr/") {
  state$objects[[paste0(bucket, "/", prefix, "zarr.json")]] <-
    charToRaw('{"zarr_format": 3, "node_type": "group"}')
}

# ==== Reading =================================================================

test_that("S3 store reads a v3 hierarchy through open_zarr()", {
  state <- local_fake_s3()
  src <- tempfile(fileext = ".zarr")
  z <- create_zarr(src)
  z$add_group("/", "grp")
  def <- define_array("float64", c(6L, 4L)); def$chunk_shape <- c(3L, 2L)
  x <- matrix(as.numeric(1:24), 6L, 4L)
  z$add_array("/grp", "a", def)$write(x)
  z[["/grp"]]$set_attribute("title", "on S3")
  z[["/grp"]]$save()
  upload_dir(state, src, "bkt", "data/store.zarr/")

  s3z <- open_zarr("s3://bkt/data/store.zarr")
  expect_s3_class(s3z$store, "zarr_s3store")
  expect_equal(s3z$store$friendlyClassName, "S3 store")
  expect_equal(s3z$store$root, "s3://bkt/data/store.zarr/")
  expect_equal(s3z$store$uri, "s3://bkt/data/store.zarr/")
  expect_equal(s3z$groups, c("/", "/grp"))
  expect_equal(s3z[["/grp"]]$attributes$title, "on S3")
  expect_equal(s3z[["/grp/a"]]$read(), x)
  expect_true(state$config$credentials$anonymous)
})

test_that("S3 store parses AWS https URLs", {
  state <- local_fake_s3()
  new_bucket_store(state, "bkt", "store.zarr/")
  z <- open_zarr("https://bkt.s3.eu-west-1.amazonaws.com/store.zarr")
  expect_s3_class(z$store, "zarr_s3store")
  expect_equal(state$config$region, "eu-west-1")
})

test_that("S3 store passes credentials and endpoint settings to paws", {
  state <- local_fake_s3()
  new_bucket_store(state)
  zarr_s3store$new("bkt", "data/store.zarr", profile = "dev")
  expect_equal(state$config$credentials, list(profile = "dev"))

  zarr_s3store$new("bkt", "data/store.zarr", access_key = "AK", secret_key = "SK", session_token = "ST")
  expect_equal(state$config$credentials$creds,
               list(access_key_id = "AK", secret_access_key = "SK", session_token = "ST"))

  zarr_s3store$new("bkt", "data/store.zarr", endpoint = "https://minio.local", region = "x")
  expect_equal(state$config$endpoint, "https://minio.local")
  expect_true(state$config$s3_force_path_style)
  expect_equal(state$config$region, "x")

  zarr_s3store$new("bkt", "data/store.zarr", anonymous = FALSE)
  expect_null(state$config$credentials)
})

test_that("S3 store byte-range reads", {
  state <- local_fake_s3()
  new_bucket_store(state)
  state$objects[["bkt/data/store.zarr/blob"]] <- as.raw(0:9)
  s <- zarr_s3store$new("bkt", "data/store.zarr")
  expect_identical(s$get("blob"), as.raw(0:9))
  expect_identical(s$get("blob", byte_range = 7L), as.raw(7:9))
  expect_identical(s$get("blob", byte_range = -3L), as.raw(7:9))
  expect_identical(s$get("blob", byte_range = c(2L, 5L)), as.raw(2:4))
  expect_null(s$get("missing"))
})

test_that("S3 store reads a sharded array", {
  state <- local_fake_s3()
  upload_dir(state, test_path("testdata/sharded_test.zarr"), "bkt", "sharded.zarr/")
  local <- open_zarr(test_path("testdata/sharded_test.zarr"))
  z <- open_zarr("s3://bkt/sharded.zarr")
  for (nm in c("/float1d", "/float2d", "/int3d"))
    expect_equal(z[[nm]]$read(), local[[nm]]$read(), info = nm)
})

test_that("S3 store reports errors other than a missing key", {
  state <- local_fake_s3()
  new_bucket_store(state)
  state$objects[["bkt/data/store.zarr/blob"]] <- as.raw(1)
  s <- zarr_s3store$new("bkt", "data/store.zarr")
  state$fail_on <- "blob"
  expect_error(s$get("blob"), "S3 error on key blob")
})

test_that("S3 store errors when there is no Zarr store at the prefix", {
  state <- local_fake_s3()
  expect_error(zarr_s3store$new("bkt", "nothing/here"), "No compatible store found at s3://bkt/nothing/here")
})

# ==== Zarr v2 =================================================================

v2_files <- list(
  ".zgroup"            = '{"zarr_format": 2}',
  ".zattrs"            = '{"title": "v2 on S3"}',
  "grp/.zgroup"        = '{"zarr_format": 2}',
  "grp/temp/.zarray"   = '{"zarr_format": 2, "shape": [2, 3], "chunks": [2, 3], "dtype": "<i4",
    "compressor": null, "fill_value": 0, "filters": null, "order": "C"}',
  "grp/temp/.zattrs"   = '{"units": "K"}'
)

upload_v2 <- function(state, consolidated) {
  for (f in names(v2_files))
    state$objects[[paste0("bkt/v2.zarr/", f)]] <- charToRaw(v2_files[[f]])
  state$objects[["bkt/v2.zarr/grp/temp/0.0"]] <- writeBin(1:6, raw(), size = 4L, endian = "little")
  if (consolidated) {
    meta <- lapply(v2_files, jsonlite::fromJSON, simplifyVector = FALSE)
    state$objects[["bkt/v2.zarr/.zmetadata"]] <- charToRaw(jsonlite::toJSON(
      list(zarr_consolidated_format = 1L, metadata = meta), auto_unbox = TRUE, null = "null"))
  }
}

test_that("S3 store reads a v2 hierarchy without consolidated metadata", {
  state <- local_fake_s3()
  upload_v2(state, consolidated = FALSE)
  z <- open_zarr("s3://bkt/v2.zarr")
  expect_equal(z$version, 2L)
  expect_equal(z$groups, c("/", "/grp"))
  expect_equal(z$root$attributes$title, "v2 on S3")
  expect_equal(z[["/grp/temp"]]$attributes$units, "K")
  expect_equal(z[["/grp/temp"]]$read(), matrix(1:6, 2L, 3L, byrow = TRUE))
})

test_that("S3 store reads a v2 hierarchy with consolidated metadata", {
  state <- local_fake_s3()
  upload_v2(state, consolidated = TRUE)
  z <- open_zarr("s3://bkt/v2.zarr")
  expect_equal(z$groups, c("/", "/grp"))
  expect_equal(z[["/grp/temp"]]$attributes$units, "K")
  expect_equal(z[["/grp/temp"]]$read(), matrix(1:6, 2L, 3L, byrow = TRUE))
  expect_true(z$store$exists("grp/temp"))
  expect_null(z$store$get_metadata("nope/"))
})

# ==== Writing =================================================================

test_that("S3 store writes groups and arrays that read back", {
  state <- local_fake_s3()
  new_bucket_store(state)
  z <- open_zarr("s3://bkt/data/store.zarr", read_only = FALSE)
  z$add_group("/", "grp")
  def <- define_array("int32", c(4L, 4L)); def$chunk_shape <- c(2L, 2L)
  z$add_array("/grp", "a", def)$write(matrix(1:16, 4L, 4L))

  z2 <- open_zarr("s3://bkt/data/store.zarr")
  expect_equal(z2$groups, c("/", "/grp"))
  expect_equal(z2[["/grp/a"]]$read(), matrix(1:16, 4L, 4L))
  expect_true(z2$store$is_group("/grp"))
  expect_false(z2$store$is_group("/grp/a"))
})

test_that("S3 store key operations", {
  state <- local_fake_s3()
  new_bucket_store(state)
  s <- zarr_s3store$new("bkt", "data/store.zarr")
  s$set("g/a/c.0", as.raw(1:4))
  s$set("g/a/c.1", as.raw(1:6))
  s$set("g/a/zarr.json", charToRaw("{}"))
  s$set("g/zarr.json", charToRaw("{}"))

  expect_true(s$exists("g/a/c.0"))
  expect_false(s$exists("g/a/c.9"))
  expect_equal(s$getsize("g/a/c.1"), 6L)
  expect_error(s$getsize("g/a/c.9"), "Key not found")
  expect_equal(s$getsize_prefix("g/a/"), 4 + 6 + 2)
  expect_setequal(s$list_dir("g/"), c("a", "zarr.json"))
  expect_setequal(s$list_chunks("g/a/"), c("g/a/c.0", "g/a/c.1"))
  expect_true("/g/a/c.0" %in% s$list_prefix("g/"))
  expect_true("/zarr.json" %in% s$list())
  expect_false(s$is_empty("g/"))
  expect_true(s$is_empty("h/"))

  s$set_if_not_exists("g/a/c.0", as.raw(9))
  expect_identical(s$get("g/a/c.0"), as.raw(1:4))
  s$set_if_not_exists("g/a/c.2", as.raw(9))
  expect_identical(s$get("g/a/c.2"), as.raw(9))

  s$rename("g/a/c.2", "g/a/c.3")
  expect_false(s$exists("g/a/c.2"))
  expect_identical(s$get("g/a/c.3"), as.raw(9))

  expect_true(s$erase("g/a/c.3"))
  expect_false(s$exists("g/a/c.3"))
  expect_true(s$erase_prefix("g/a/"))
  expect_true(s$is_empty("g/a/"))
  expect_true(s$erase_prefix("nothing/"))
  expect_true(s$clear())
  expect_identical(s$list(), character(0))
})

test_that("S3 store opened read-only does not write", {
  state <- local_fake_s3()
  new_bucket_store(state)
  s <- zarr_s3store$new("bkt", "data/store.zarr", read_only = TRUE)
  n <- length(ls(state$objects))
  s$set("k", as.raw(1))
  s$set_if_not_exists("k", as.raw(1))
  s$set_metadata("g/", list(zarr_format = 3L, node_type = "group"))
  expect_false(s$erase("zarr.json"))
  expect_false(s$erase_prefix(""))
  expect_false(s$clear())
  expect_length(ls(state$objects), n)
  expect_error(s$create_group("/", "g"), "read-only")
  expect_error(s$create_array("/", "a", list()), "read-only")
})

# ==== s3_list_dir() ===========================================================

test_that("s3_list_dir() lists prefixes and keys across pages", {
  state <- local_fake_s3()
  for (k in c("a.zarr/zarr.json", "b.zarr/zarr.json", "c.zarr/zarr.json", "README.md"))
    state$objects[[paste0("bkt/root/", k)]] <- as.raw(1)
  expect_setequal(s3_list_dir("bkt", "root"),
                  c("root/a.zarr/", "root/b.zarr/", "root/c.zarr/", "root/README.md"))
  expect_true(state$config$credentials$anonymous)

  s3_list_dir("bkt", endpoint = "https://minio.local", profile = "dev")
  expect_equal(state$config$region, "us-east-1")
  expect_true(state$config$s3_force_path_style)
  expect_equal(state$config$credentials, list(profile = "dev"))

  s3_list_dir("bkt", access_key = "AK", secret_key = "SK")
  expect_equal(state$config$credentials$creds$access_key_id, "AK")
})
