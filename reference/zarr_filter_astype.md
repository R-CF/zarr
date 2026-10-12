# Zarr v.2 "astype" filter

The "astype" filter converts data to another data type. Decoding
converts the data back to the decoded data type, truncating towards zero
when converting floating point values to an integer type.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_astype`

## Methods

### Public methods

- [`zarr_filter_astype$new()`](#method-zarr_filter_astype-initialize)

- [`zarr_filter_astype$decode()`](#method-zarr_filter_astype-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_astype$new()`

Create a new "astype" filter.

#### Usage

    zarr_filter_astype$new(configuration)

#### Arguments

- `configuration`:

  A list with elements `encode_dtype` and `decode_dtype`.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_astype$decode()`

Decode the data.

#### Usage

    zarr_filter_astype$decode(data)

#### Arguments

- `data`:

  The encoded data.

#### Returns

The decoded data.
