# Zarr v.2 "packbits" filter

The "packbits" filter packs logical values into bits, most significant
bit first. The first byte of the encoded data gives the number of bits
that pad the final byte.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_packbits`

## Methods

### Public methods

- [`zarr_filter_packbits$new()`](#method-zarr_filter_packbits-initialize)

- [`zarr_filter_packbits$decode()`](#method-zarr_filter_packbits-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_packbits$new()`

Create a new "packbits" filter.

#### Usage

    zarr_filter_packbits$new(configuration = list())

#### Arguments

- `configuration`:

  Ignored, the filter has no configuration parameters.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_packbits$decode()`

Decode the data.

#### Usage

    zarr_filter_packbits$decode(data)

#### Arguments

- `data`:

  The encoded data, an integer vector of byte values.

#### Returns

A logical vector with the decoded data.
