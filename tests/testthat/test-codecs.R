# Tests for the individual codecs and for codec chains in array_builder.

dt_f64 <- function() zarr_data_type$new("float64")

# ==== Codec base class and printing ===========================================

test_that("codec mode and metadata fragment", {
  cdc <- zarr_codec_gzip$new(list(level = 3))
  expect_equal(cdc$mode, "bytes -> bytes")
  expect_equal(cdc$from, "bytes")
  expect_equal(cdc$to, "bytes")
  expect_equal(cdc$metadata_fragment(), list(name = "gzip", configuration = list(level = 3)))
  expect_equal(zarr_codec_crc32c$new()$metadata_fragment(), list(name = "crc32c"))
})

test_that("print() shows each codec's configuration", {
  expect_output(print(zarr_codec_transpose$new(3L)), "order: \\[2, 1, 0\\]")
  expect_output(print(zarr_codec_bytes$new(dt_f64(), 4L, list(endian = "big"))), "endian: big")
  expect_output(print(zarr_codec_blosc$new(dt_f64())), "compressor: zstd")
  expect_output(print(zarr_codec_zstd$new()), "level: 6")
  expect_output(print(zarr_codec_gzip$new()), "level: 6")
  expect_output(print(zarr_codec_crc32c$new()), "Mode         : bytes -> bytes")
})

test_that("print() of the sharding codec shows its configuration", {
  cdc <- zarr_codec_sharding$new(list(chunk_shape = c(2L, 2L), index_location = "end",
                                      codecs = list(list(name = "bytes"), list(name = "gzip"))))
  expect_output(print(cdc), "chunk_shape: +\\[2, 2\\]")
  expect_output(print(cdc), "index_location: end")
  expect_output(print(cdc), "codecs: +\\[bytes, gzip\\]")
})

test_that("copy() returns an equivalent, independent codec", {
  for (cdc in list(zarr_codec_transpose$new(2L), zarr_codec_blosc$new(dt_f64()),
                   zarr_codec_zstd$new(list(level = 3)), zarr_codec_gzip$new(list(level = 2)),
                   zarr_codec_crc32c$new(), zarr_codec_vlenutf8$new(),
                   zarr_codec_ucs4$new(2L, list(endian = "little", width = 3L)),
                   zarr_codec_sharding$new(list(chunk_shape = 2L)))) {
    cp <- cdc$copy()
    expect_false(identical(cp, cdc))
    expect_equal(cp$metadata_fragment(), cdc$metadata_fragment())
  }
})

# ==== Transpose ===============================================================

test_that("transpose with the default order is a no-op", {
  x <- array(1:24, 2:4)
  cdc <- zarr_codec_transpose$new(3L)
  expect_identical(cdc$encode(x), x)
  expect_identical(cdc$decode(x), x)
})

test_that("transpose with another order round-trips", {
  x <- array(1:24, 2:4)
  for (ord in list(c(0L, 1L, 2L), c(1L, 2L, 0L), c(2L, 0L, 1L))) {
    cdc <- zarr_codec_transpose$new(3L, list(order = ord))
    enc <- cdc$encode(x)
    expect_false(identical(dim(enc), dim(x)) && identical(enc, x), info = paste(ord, collapse = ","))
    expect_identical(cdc$decode(enc), x, info = paste(ord, collapse = ","))
  }
})

test_that("transpose order can be changed", {
  cdc <- zarr_codec_transpose$new(2L)
  cdc$order <- c(0L, 1L)
  expect_equal(cdc$order, c(0L, 1L))
  expect_error(cdc$order <- c(0L, 0L), "does not match the shape")
})

# ==== Bytes-to-bytes codecs ===================================================

test_that("gzip round-trips and honours its level", {
  raw <- as.raw(rep(1:50, 20))
  cdc <- zarr_codec_gzip$new()
  expect_identical(cdc$decode(cdc$encode(raw)), raw)
  cdc$level <- 9
  expect_equal(cdc$level, 9L)
  expect_identical(cdc$decode(cdc$encode(raw)), raw)
  expect_error(cdc$level <- 10, "between 0 and 9")
})

test_that("zstd round-trips and honours its level", {
  raw <- as.raw(rep(1:50, 20))
  cdc <- zarr_codec_zstd$new()
  expect_identical(cdc$decode(cdc$encode(raw)), raw)
  cdc$level <- 19
  expect_equal(cdc$level, 19L)
  expect_identical(cdc$decode(cdc$encode(raw)), raw)
  expect_error(cdc$level <- 0, "between 1 and 20")
})

test_that("crc32c appends a checksum that decode() verifies", {
  cdc <- zarr_codec_crc32c$new()
  # Payloads whose CRC32C has the high bit clear and set, respectively
  for (raw in list(charToRaw("abc"), as.raw(0:255), charToRaw("zarr"))) {
    enc <- cdc$encode(raw)
    expect_length(enc, length(raw) + 4L)
    expect_identical(enc[length(raw) + 1:4],
                     rev(digest::digest(raw, algo = "crc32c", serialize = FALSE, raw = TRUE)))
    expect_silent(dec <- cdc$decode(enc))
    expect_identical(dec, raw)
  }
})

test_that("crc32c warns on a corrupted payload", {
  cdc <- zarr_codec_crc32c$new()
  enc <- cdc$encode(charToRaw("zarr"))
  enc[1L] <- as.raw(0)
  expect_warning(cdc$decode(enc), "Checksum failed")
})

test_that("blosc round-trips and its fields can be set", {
  cdc <- zarr_codec_blosc$new(dt_f64(), list(cname = "lz4", clevel = 5L))
  raw <- writeBin(seq(0, 10, length.out = 200), raw())
  expect_identical(cdc$decode(cdc$encode(raw)), raw)

  cdc$cname <- "zlib"
  cdc$clevel <- 9
  cdc$shuffle <- "noshuffle"
  cdc$typesize <- 4L
  cdc$blocksize <- 256L
  expect_equal(list(cdc$cname, cdc$clevel, cdc$shuffle, cdc$typesize, cdc$blocksize),
               list("zlib", 9L, "noshuffle", 4L, 256L))
  expect_identical(cdc$decode(cdc$encode(raw)), raw)
  expect_error(cdc$cname <- "snappy", "bad compression name")
})

test_that("blosc picks shuffle from the data type", {
  expect_equal(zarr_codec_blosc$new(zarr_data_type$new("uint8"))$shuffle, "noshuffle")
  expect_equal(zarr_codec_blosc$new(zarr_data_type$new("int32"))$shuffle, "shuffle")
  expect_equal(zarr_codec_blosc$new(dt_f64())$shuffle, "bitshuffle")
})

# ==== Codec chains through arrays =============================================

roundtrip_with <- function(codec, configuration = NULL, x = matrix(rnorm(60), 6L, 10L)) {
  def <- define_array("float64", dim(x))
  def$chunk_shape <- c(3L, 5L)
  def$remove_codec("blosc")
  def$add_codec(codec, configuration)
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_array("/", "a", def)$write(x)
  open_zarr(fn)[["/a"]]$read()
}

test_that("arrays round-trip with gzip, zstd and crc32c", {
  x <- matrix(rnorm(60), 6L, 10L)
  expect_equal(roundtrip_with("gzip", list(level = 5), x), x)
  expect_equal(roundtrip_with("zstd", list(level = 3), x), x)
  expect_warning(expect_equal(roundtrip_with("crc32c", NULL, x), x), NA)
})

test_that("string arrays round-trip through vlen-utf8 after re-opening", {
  x <- matrix(c("a", "", "µs", "東京", "long string value", NA), 2L, 3L)
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_array("/", "s", define_array("string", c(2L, 3L)))$write(x)
  y <- open_zarr(fn)[["/s"]]$read()
  expect_equal(y[!is.na(x)], x[!is.na(x)])
})

# ==== array_builder ===========================================================

test_that("array_builder print() and JSON metadata", {
  def <- define_array("int16", c(10L, 20L))
  expect_output(print(def), "<Zarr array metadata> VALID")
  expect_output(print(array_builder$new()), "INCOMPLETE")
  json <- def$metadata("json")
  expect_s3_class(json, "json")
  expect_equal(jsonlite::fromJSON(json)$data_type, "int16")
})

test_that("array_builder can be initialised from a JSON document", {
  json <- define_array("float32", c(4L, 5L))$metadata("json")
  ab <- array_builder$new(json)
  expect_equal(ab$data_type$data_type, "float32")
  expect_equal(ab$shape, c(4L, 5L))
  expect_true(ab$is_valid())
})

test_that("array_builder codec_info lists the codec chain", {
  info <- define_array("float64", c(10L, 20L))$codec_info
  expect_s3_class(info, "data.frame")
  expect_equal(info$codec, c("transpose", "bytes", "blosc"))
  expect_equal(info$mode, c("array -> array", "array -> bytes", "bytes -> bytes"))
})

test_that("array_builder inserts codecs at a position", {
  def <- define_array("float64", c(10L, 20L))
  def$add_codec("crc32c", NULL, .position = 3L)
  expect_equal(names(def$codecs), c("transpose", "bytes", "crc32c", "blosc"))
  def$remove_codec("transpose")
  def$add_codec("transpose", list(order = c(1L, 0L)), .position = 1L)
  expect_equal(names(def$codecs)[1L], "transpose")
  expect_error(def$add_codec("gzip", NULL, .position = 1L), "First codec must use")
})

test_that("array_builder portable flag toggles the transpose codec", {
  def <- define_array("float64", c(10L, 20L))
  expect_false(def$portable)
  def$portable <- TRUE
  expect_true(def$portable)
  expect_false("transpose" %in% names(def$codecs))
  def$portable <- FALSE
  expect_true("transpose" %in% names(def$codecs))
})

test_that("array_builder data type and format changes", {
  def <- define_array("float64", c(10L, 20L))
  def$data_type <- "int32"
  expect_equal(def$data_type$data_type, "int32")
  def$data_type_from_storage.mode <- "double"
  expect_equal(def$data_type$data_type, "float64")
  expect_equal(def$format, 3L)
  def$format <- 2
  expect_equal(def$format, 2L)
  expect_null(def$data_type)
})

test_that("array_builder fill values for special floats and uint types", {
  def <- define_array("float64", 10L)
  def$fill_value <- "Infinity"
  expect_equal(def$fill_value, Inf)
  def$fill_value <- "-Infinity"
  expect_equal(def$fill_value, -Inf)
  expect_error(def$fill_value <- "huge", "Invalid `fill_value`")
  def$data_type <- "uint16"
  def$fill_value <- 7
  expect_identical(def$fill_value, 7L)
  def$data_type <- "uint32"
  def$fill_value <- 4294967295
  expect_identical(def$fill_value, bit64::as.integer64("4294967295"))
  def$fill_value <- -1
  expect_true(is.na(def$fill_value))
  def$data_type <- "int32"
  expect_error(def$fill_value <- "x", "Invalid `fill_value`")
})
