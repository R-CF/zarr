# Zarr blosc codec

The Zarr "blosc" codec offers a number of compression options to reduce
the size of a raw vector prior to storing, and uncompressing when
reading.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_blosc`

## Active bindings

- `cname`:

  Set or retrieve the name of the compression algorithm. Must be one of
  "blosclz", "lz4", "lz4hc", "zstd" or "zlib".

- `clevel`:

  Set or retrieve the compression level. Must be an integer between 0
  (no compression) and 9 (maximum compression).

- `shuffle`:

  Set or retrieve the data shuffling of the compression algorithm. Must
  be one of "shuffle", "noshuffle" or "bitshuffle".

- `typesize`:

  Set or retrieve the size in bytes of the data type being compressed.
  It is highly recommended to leave this at the automatically determined
  value.

- `blocksize`:

  Set or retrieve the size in bytes of the blocks being compressed. It
  is highly recommended to leave this at a value of 0 such that the
  blosc library will automatically determine the optimal value.

## Methods

### Public methods

- [`zarr_codec_blosc$new()`](#method-zarr_codec_blosc-new)

- [`zarr_codec_blosc$copy()`](#method-zarr_codec_blosc-copy)

- [`zarr_codec_blosc$encode()`](#method-zarr_codec_blosc-encode)

- [`zarr_codec_blosc$decode()`](#method-zarr_codec_blosc-decode)

Inherited methods

- [`zarr::zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr::zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### Method `new()`

Create a new "blosc" codec object. The typesize argument is taken from
the data type of the array passed in through the `data_type` argument
and the shuffle argument is chosen based on the `data_type`.

#### Usage

    zarr_codec_blosc$new(data_type, configuration = NULL)

#### Arguments

- `data_type`:

  The
  [zarr_data_type](https://r-cf.github.io/zarr/reference/zarr_data_type.md)
  instance of the Zarr array that this codec is used for.

- `configuration`:

  Optional. A list with the configuration parameters for this codec. If
  not given, the default compression of "zstd" with level 1 will be
  used.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_blosc$copy()

#### Returns

An instance of `zarr_codec_blosc`.

------------------------------------------------------------------------

### Method `encode()`

This method compresses a data object using the "blosc" compression
library.

#### Usage

    zarr_codec_blosc$encode(data)

#### Arguments

- `data`:

  The raw vector to be compressed.

#### Returns

A raw vector with compressed data.

------------------------------------------------------------------------

### Method `decode()`

This method decompresses a data object using the "blosc" compression
library.

#### Usage

    zarr_codec_blosc$decode(data)

#### Arguments

- `data`:

  The raw vector to be decoded.

#### Returns

A raw vector with the decoded data.
