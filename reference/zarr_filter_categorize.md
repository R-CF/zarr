# Zarr v.2 "categorize" filter

The "categorize" filter encodes character strings as the 1-based index
into a vector of labels. Strings that are not a label are encoded as 0,
which decodes to an empty string, like with Numcodecs.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_categorize`

## Methods

### Public methods

- [`zarr_filter_categorize$new()`](#method-zarr_filter_categorize-initialize)

- [`zarr_filter_categorize$decode()`](#method-zarr_filter_categorize-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_categorize$new()`

Create a new "categorize" filter.

#### Usage

    zarr_filter_categorize$new(configuration)

#### Arguments

- `configuration`:

  A list with elements `labels`, `dtype` and, optionally, `astype`.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_categorize$decode()`

Decode the data.

#### Usage

    zarr_filter_categorize$decode(data)

#### Arguments

- `data`:

  The encoded data.

#### Returns

A character vector with the decoded data.
