# Zarr v.2 "shuffle" filter

The "shuffle" filter rearranges the bytes of the data such that the
first bytes of all elements come first, then all second bytes, and so
on. This improves compression of the data.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_shuffle`

## Methods

### Public methods

- [`zarr_filter_shuffle$new()`](#method-zarr_filter_shuffle-initialize)

- [`zarr_filter_shuffle$decode()`](#method-zarr_filter_shuffle-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_shuffle$new()`

Create a new "shuffle" filter.

#### Usage

    zarr_filter_shuffle$new(configuration)

#### Arguments

- `configuration`:

  A list with element `elementsize`, the size of the data elements in
  bytes, by default 4.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_shuffle$decode()`

Decode the data.

#### Usage

    zarr_filter_shuffle$decode(data)

#### Arguments

- `data`:

  The encoded data, a raw vector.

#### Returns

A raw vector with the decoded data.
