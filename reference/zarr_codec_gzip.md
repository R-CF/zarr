# Zarr gzip codec

The Zarr "gzip" codec compresses a raw vector prior to storing, and
uncompresses the raw vector when reading.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_gzip`

## Active bindings

- `level`:

  The compression level of the gzip codec, an integer value between 0L
  (no compression) and 9 (maximum compression).

## Methods

### Public methods

- [`zarr_codec_gzip$new()`](#method-zarr_codec_gzip-new)

- [`zarr_codec_gzip$copy()`](#method-zarr_codec_gzip-copy)

- [`zarr_codec_gzip$encode()`](#method-zarr_codec_gzip-encode)

- [`zarr_codec_gzip$decode()`](#method-zarr_codec_gzip-decode)

Inherited methods

- [`zarr::zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr::zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### Method `new()`

Create a new "gzip" codec object.

#### Usage

    zarr_codec_gzip$new(configuration = NULL)

#### Arguments

- `configuration`:

  Optional. A list with the configuration parameters for this codec. The
  element `level` specifies the compression level of this codec, ranging
  from 0 (no compression) to 9 (maximum compression).

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_gzip$copy()

#### Returns

An instance of `zarr_codec_gzip`.

------------------------------------------------------------------------

### Method `encode()`

This method encodes a data object.

#### Usage

    zarr_codec_gzip$encode(data)

#### Arguments

- `data`:

  The data to be encoded.

#### Returns

The encoded data object.

------------------------------------------------------------------------

### Method `decode()`

This method decodes a data object.

#### Usage

    zarr_codec_gzip$decode(data)

#### Arguments

- `data`:

  The data to be decoded.

#### Returns

The decoded data object.
