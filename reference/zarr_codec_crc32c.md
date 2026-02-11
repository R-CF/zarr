# Zarr CRC32C codec

The Zarr "CRC32C" codec computes a 32-bit checksum of a raw vector. Upon
encoding the codec appends the checksum to the end of the vector. When
decoding, the final 4 bytes from the raw vector are extracted and
compared to the checksum of the remainder of the raw vector - if the two
don't match a warning is generated.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_crc32c`

## Methods

### Public methods

- [`zarr_codec_crc32c$new()`](#method-zarr_codec_crc32c-new)

- [`zarr_codec_crc32c$copy()`](#method-zarr_codec_crc32c-copy)

- [`zarr_codec_crc32c$encode()`](#method-zarr_codec_crc32c-encode)

- [`zarr_codec_crc32c$decode()`](#method-zarr_codec_crc32c-decode)

Inherited methods

- [`zarr::zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr::zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### Method `new()`

Create a new "crc32c" codec object.

#### Usage

    zarr_codec_crc32c$new()

#### Arguments

- `configuration`:

  Optional. A list with the configuration parameters for this codec but
  since this codec doesn't have any the argument is always ignored.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_crc32c$copy()

#### Returns

An instance of `zarr_codec_crc32c`.

------------------------------------------------------------------------

### Method `encode()`

This method computes the CRC32C checksum of a data object and appends it
to the data object.

#### Usage

    zarr_codec_crc32c$encode(data)

#### Arguments

- `data`:

  A raw vector whose checksum to compute.

#### Returns

The input `data` raw vector with the 32-bit checksum appended to it.

------------------------------------------------------------------------

### Method `decode()`

This method extracts the CRC32C checksum from the trailing 32-bits of a
data object. It then computes the CRC32C checksum from the data object
(less the trailing 32-bits) and compares the two values. If the values
differ, a warning will be issued.

#### Usage

    zarr_codec_crc32c$decode(data)

#### Arguments

- `data`:

  The raw vector whose checksum to verify.

#### Returns

The `data` raw vector with the trailing 32-bits removed.
