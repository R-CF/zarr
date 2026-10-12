# Tests for Zarr v2 filters. The encoded chunks were produced with Numcodecs
# 0.17 and are given here as hex strings, so the tests do not depend on the
# package's own (non-existent) encoders.

hex2raw <- function(h)
  as.raw(strtoi(substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)), 16L))

# Write a single-chunk v2 array with `filters` (a JSON string) and chunk `data`
# (a hex string or raw vector) and return the opened root array. The fill value
# is null so that no data is masked when reading.
v2_filtered <- function(dtype, shape, filters, data, order = "C") {
  root <- tempfile(fileext = ".zarr")
  dir.create(root)
  writeLines(sprintf('{"zarr_format": 2, "shape": [%s], "chunks": [%s], "dtype": "%s",
    "compressor": null, "fill_value": null, "filters": %s, "order": "%s"}',
    paste(shape, collapse = ", "), paste(shape, collapse = ", "), dtype, filters, order),
    file.path(root, ".zarray"))
  if (is.character(data)) data <- hex2raw(data)
  writeBin(data, file.path(root, paste(rep("0", length(shape)), collapse = ".")))
  arr <- open_zarr(root)$root
  arr$raw_read <- TRUE
  arr
}

# ==== Pipeline construction ===================================================

test_that("array -> array filters go before the bytes codec, bytes -> bytes after", {
  arr <- v2_filtered("<i4", 5, '[{"id": "delta", "dtype": "<i4", "astype": "<i2"},
    {"id": "shuffle", "elementsize": 2}, {"id": "crc32"}]', "0ab38f0b0a010203040000000000")
  expect_equal(names(arr$codecs),
               c("numcodecs.delta", "bytes", "numcodecs.shuffle", "numcodecs.crc32"))
})

test_that("filter configuration drops the v2 id", {
  arr <- v2_filtered("<i4", 5, '[{"id": "delta", "dtype": "<i4", "astype": "<i2"}]', "64000200fdff6d072bf8")
  expect_equal(arr$codecs[["numcodecs.delta"]]$configuration, list(dtype = "<i4", astype = "<i2"))
})

test_that("the bytes codec deserializes the encoded data type", {
  arr <- v2_filtered("<f8", 3, '[{"id": "fixedscaleoffset", "scale": 4, "offset": 0,
    "dtype": "<f8", "astype": ">i2"}]', "00320035fffc")
  expect_equal(arr$codecs$bytes$endian, "big")
})

test_that("a vlen-utf8 filter is the array -> bytes codec", {
  arr <- v2_filtered("|O", 2, '[{"id": "vlen-utf8"}]', "0200000001000000610300000062c3a9")
  expect_equal(names(arr$codecs), "vlen-utf8")
  expect_equal(arr$read(), c("a", "bé"))
})

test_that("a bytes -> bytes filter before an array -> array filter is an error", {
  expect_error(v2_filtered("<i4", 3, '[{"id": "shuffle", "elementsize": 4},
    {"id": "delta", "dtype": "<i4"}]', raw(12)), "cannot be expressed in Zarr v.3")
})

test_that("an unsupported filter is an error", {
  expect_error(v2_filtered("<i4", 3, '[{"id": "pickle"}]', raw(12)), "Unsupported Zarr v.2 filter: pickle")
})

test_that("filters cannot encode", {
  arr <- v2_filtered("<i4", 5, '[{"id": "delta", "dtype": "<i4", "astype": "<i2"}]', "64000200fdff6d072bf8")
  expect_error(arr$codecs[["numcodecs.delta"]]$encode(1:5), "can only decode")
})

# ==== delta ===================================================================

test_that("delta decodes from a smaller integer type", {
  arr <- v2_filtered("<i4", 5, '[{"id": "delta", "dtype": "<i4", "astype": "<i2"}]', "64000200fdff6d072bf8")
  expect_equal(arr$read(), c(100L, 102L, 99L, 2000L, -5L))
})

test_that("delta wraps around for unsigned integers", {
  arr <- v2_filtered("|u1", 4, '[{"id": "delta", "dtype": "|u1", "astype": "|u1"}]', "fa0bfefc")
  expect_equal(arr$read(), c(250L, 5L, 3L, 255L))
})

test_that("delta decodes uint32", {
  arr <- v2_filtered("<u4", 3, '[{"id": "delta", "dtype": "<u4", "astype": "<u4"}]', "00286bee0ad89411f5ffffff")
  expect_equal(as.character(arr$read()), c("4000000000", "10", "4294967295"))
})

test_that("delta decodes int64", {
  arr <- v2_filtered("<i8", 3, '[{"id": "delta", "dtype": "<i8", "astype": "<i8"}]',
                     "0068e5cf8b010000f40100000000000006ffffffffffffff")
  expect_equal(as.character(arr$read()), c("1700000000000", "1700000000500", "1700000000250"))
})

test_that("delta runs along the storage order of an F-order chunk", {
  arr <- v2_filtered("<i4", c(3, 4), '[{"id": "delta", "dtype": "<i4", "astype": "<i4"}]',
    "000000001000000030000000c1ffffff1800000038000000b3ffffff2000000040000000a5ffffff2800000048000000",
    order = "F")
  expect_equal(arr$read(), matrix((0:11)^2, 3, 4, byrow = TRUE))
})

# ==== fixedscaleoffset ========================================================

test_that("fixedscaleoffset decodes to float", {
  arr <- v2_filtered("<f8", 10, '[{"id": "fixedscaleoffset", "scale": 10, "offset": 1000,
    "dtype": "<f8", "astype": "|u1"}]', "0001020304060708090a")
  expect_equal(arr$read(), 1000 + c(0:4, 6:10) / 10)
})

test_that("fixedscaleoffset decodes a big-endian encoded type", {
  arr <- v2_filtered("<f8", 3, '[{"id": "fixedscaleoffset", "scale": 4, "offset": 0,
    "dtype": "<f8", "astype": ">i2"}]', "00320035fffc")
  expect_equal(arr$read(), c(12.5, 13.25, -1))
})

test_that("fixedscaleoffset truncates to an integer type", {
  arr <- v2_filtered("<i4", 4, '[{"id": "fixedscaleoffset", "scale": 3, "offset": 5,
    "dtype": "<i4", "astype": "<i2"}]', "060009000c00e8ff")
  expect_equal(arr$read(), c(7L, 8L, 9L, -3L))
})

# ==== Lossy filters ===========================================================

test_that("quantize decodes as the identity", {
  arr <- v2_filtered("<f8", 5, '[{"id": "quantize", "digits": 2, "dtype": "<f8", "astype": "<f8"}]',
    "0000000000000000000000000000d03f000000000000e03f000000000000e83f000000000000f03f")
  expect_equal(arr$read(), c(0, 0.25, 0.5, 0.75, 1))
})

test_that("bitround decodes as the identity", {
  arr <- v2_filtered("<f4", 3, '[{"id": "bitround", "keepbits": 6}]', "00008c3f00000c4000005440")
  expect_equal(arr$read(), c(1.09375, 2.1875, 3.3125))
})

# ==== astype, categorize, packbits ============================================

test_that("astype decodes float32 to float64", {
  arr <- v2_filtered("<f8", 3, '[{"id": "astype", "encode_dtype": "<f4", "decode_dtype": "<f8"}]',
                     "0000c03f000010c07684df50")
  expect_equal(arr$read(), c(1.5, -2.25, 3e10), tolerance = 1e-7)
})

test_that("categorize decodes labels, with 0 as an empty string", {
  arr <- v2_filtered("|O", 5, '[{"id": "categorize", "labels": ["female", "male"],
    "dtype": "|O", "astype": "|u1"}]', "0201010002")
  expect_equal(arr$read(), c("male", "female", "female", "", "male"))
})

test_that("packbits decodes and drops the padding bits", {
  arr <- v2_filtered("|b1", 11, '[{"id": "packbits"}]', "059d20")
  expect_equal(arr$read(), c(TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE))
})

# ==== shuffle =================================================================

test_that("shuffle restores the byte order of the elements", {
  arr <- v2_filtered("<f8", 3, '[{"id": "shuffle", "elementsize": 8}]',
                     "00009c00007500000000008800003c0000e4f800373fc07e")
  expect_equal(arr$read(), c(1.5, -2, 1e300))
})

# ==== Checksums ===============================================================

test_that("crc32 strips a leading checksum", {
  arr <- v2_filtered("<i4", 3, '[{"id": "crc32"}]', "9322e0b0010000000200000003000000")
  expect_no_warning(expect_equal(arr$read(), 1:3))
})

test_that("crc32 strips a trailing checksum", {
  arr <- v2_filtered("<i4", 3, '[{"id": "crc32", "location": "end"}]', "0100000002000000030000009322e0b0")
  expect_no_warning(expect_equal(arr$read(), 1:3))
})

test_that("adler32 strips and verifies the checksum", {
  arr <- v2_filtered("<i4", 3, '[{"id": "adler32"}]', "07003400010000000200000003000000")
  expect_no_warning(expect_equal(arr$read(), 1:3))
})

test_that("fletcher32 verifies an odd number of bytes", {
  arr <- v2_filtered("|u1", 5, '[{"id": "fletcher32"}]', "fffe0701090010ff16")
  expect_no_warning(expect_equal(arr$read(), c(255L, 254L, 7L, 1L, 9L)))
})

test_that("checksums verify large chunks", {
  x <- as.double((0:4999 * 7919) %% 100003)
  payload <- writeBin(x, raw(), endian = "little")
  arr <- v2_filtered("<f8", 5000, '[{"id": "fletcher32"}]', c(payload, hex2raw("083c3eac")))
  expect_no_warning(expect_equal(arr$read(), x))
  arr <- v2_filtered("<f8", 5000, '[{"id": "adler32"}]', c(hex2raw("2e3b91f9"), payload))
  expect_no_warning(expect_equal(arr$read(), x))
})

test_that("a checksum mismatch gives a warning", {
  arr <- v2_filtered("<i4", 3, '[{"id": "crc32"}]', "9322e0b0010000000200000004000000")
  expect_warning(arr$read(), "Checksum failed")
})

# ==== Combined ================================================================

test_that("delta, shuffle and crc32 decode in sequence", {
  arr <- v2_filtered("<i4", 5, '[{"id": "delta", "dtype": "<i4", "astype": "<i2"},
    {"id": "shuffle", "elementsize": 2}, {"id": "crc32"}]', "0ab38f0b0a010203040000000000")
  expect_equal(arr$read(), c(10L, 11L, 13L, 16L, 20L))
})

# ==== Read-only ===============================================================

test_that("a v2 store is always read-only", {
  arr <- v2_filtered("<i4", 3, '[{"id": "crc32"}]', "9322e0b0010000000200000003000000")
  expect_true(arr$store$read_only)
  expect_error(arr$write(4:6), "read-only")
})

test_that("a v2 store ignores read_only = FALSE", {
  arr <- v2_filtered("<i4", 3, '[{"id": "crc32"}]', "9322e0b0010000000200000003000000")
  z <- open_zarr(arr$store$root, read_only = FALSE)
  expect_true(z$store$read_only)
})
