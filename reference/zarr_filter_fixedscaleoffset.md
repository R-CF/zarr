# Zarr v.2 "fixedscaleoffset" filter

The "fixedscaleoffset" filter encodes data as
`round((x - offset) * scale)`, typically in a smaller integer data type.
Decoding computes `x / scale + offset`, truncated towards zero when the
decoded data type is an integer type, like Numpy does.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_fixedscaleoffset`

## Methods

### Public methods

- [`zarr_filter_fixedscaleoffset$new()`](#method-zarr_filter_fixedscaleoffset-initialize)

- [`zarr_filter_fixedscaleoffset$decode()`](#method-zarr_filter_fixedscaleoffset-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_fixedscaleoffset$new()`

Create a new "fixedscaleoffset" filter.

#### Usage

    zarr_filter_fixedscaleoffset$new(configuration)

#### Arguments

- `configuration`:

  A list with elements `scale`, `offset`, `dtype` and, optionally,
  `astype`.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_fixedscaleoffset$decode()`

Decode the data.

#### Usage

    zarr_filter_fixedscaleoffset$decode(data)

#### Arguments

- `data`:

  The encoded data.

#### Returns

The decoded data.
