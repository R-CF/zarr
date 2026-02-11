# Zarr "zstd" codec

This class provides the codec for "zstd" compression.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_zstd`

## Active bindings

- `level`:

  The compression level of the zstd codec, an integer value between 1L
  (fast) and 20 (maximum compression).

## Methods

### Public methods

- [`zarr_codec_zstd$new()`](#method-zarr_codec_zstd-new)

- [`zarr_codec_zstd$copy()`](#method-zarr_codec_zstd-copy)

- [`zarr_codec_zstd$encode()`](#method-zarr_codec_zstd-encode)

- [`zarr_codec_zstd$decode()`](#method-zarr_codec_zstd-decode)

Inherited methods

- [`zarr::zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr::zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### Method `new()`

Create a new "zstd" codec object.

#### Usage

    zarr_codec_zstd$new(configuration = NULL)

#### Arguments

- `configuration`:

  Optional. A list with the configuration parameters for this codec. The
  element `level` specifies the compression level of this codec, ranging
  from 1 (no compression) to 20 (maximum compression).

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_zstd$copy()

#### Returns

An instance of `zarr_codec_zstd`.

------------------------------------------------------------------------

### Method `encode()`

This method encodes a raw data object.

#### Usage

    zarr_codec_zstd$encode(data)

#### Arguments

- `data`:

  The raw data to be encoded.

#### Returns

The encoded raw data object.

------------------------------------------------------------------------

### Method `decode()`

This method decodes a raw data object.

#### Usage

    zarr_codec_zstd$decode(data)

#### Arguments

- `data`:

  The raw data to be decoded.

#### Returns

The decoded raw data object.
