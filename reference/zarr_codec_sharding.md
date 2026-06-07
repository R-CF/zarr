# Zarr sharding codec

The Zarr sharding codec is not a true codec in the sense that it does
not encode or decode - that is left up to regular codec defined inside
this "codec" configuration. This implementation can read from a store
using sharding, writing is not supported.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_sharding`

## Methods

### Public methods

- [`zarr_codec_sharding$new()`](#method-zarr_codec_sharding-initialize)

- [`zarr_codec_sharding$copy()`](#method-zarr_codec_sharding-copy)

Inherited methods

- [`zarr_codec$decode()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-decode)
- [`zarr_codec$encode()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-encode)
- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### `zarr_codec_sharding$new()`

Create a new "crc32c" codec object.

#### Usage

    zarr_codec_sharding$new(configuration)

#### Arguments

- `configuration`:

  Optional. A list with the configuration parameters for this codec but
  since this codec doesn't have any the argument is always ignored.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_codec_sharding$copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_sharding$copy()

#### Returns

An instance of `zarr_codec_sharding`.
