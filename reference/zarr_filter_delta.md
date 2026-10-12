# Zarr v.2 "delta" filter

The "delta" filter encodes data as the difference between adjacent
elements, with the first element stored as is. Decoding is a cumulative
sum in the decoded data type, wrapping around on overflow for integer
data types up to 32 bits, like Numpy does. 64-bit integers do not wrap
around: an overflow yields `NA`.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_delta`

## Methods

### Public methods

- [`zarr_filter_delta$new()`](#method-zarr_filter_delta-initialize)

- [`zarr_filter_delta$decode()`](#method-zarr_filter_delta-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_delta$new()`

Create a new "delta" filter.

#### Usage

    zarr_filter_delta$new(configuration)

#### Arguments

- `configuration`:

  A list with elements `dtype` and, optionally, `astype`.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_delta$decode()`

Decode the data.

#### Usage

    zarr_filter_delta$decode(data)

#### Arguments

- `data`:

  The encoded data.

#### Returns

The decoded data.
