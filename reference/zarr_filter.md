# Zarr v.2 filters

Zarr v.2 filters are transformations of chunk data that were not
specified by Zarr v.2 itself but by the Numcodecs package that
zarr-python uses. When a Zarr v.2 store is opened, the filters become
codecs in the Zarr v.3 codec pipeline of an array, with a name of
"numcodecs.". Because Zarr v.2 stores are read-only in this package,
filters only decode data.

This class is the ancestor of all filters. It also implements the lossy
"quantize" and "bitround" filters: these reduce the precision of
floating point data upon encoding but they leave the data type
unchanged, so decoding is the identity.

The following filters are supported: "delta", "fixedscaleoffset",
"quantize", "bitround", "astype", "categorize", "packbits", "shuffle",
"crc32", "adler32" and "fletcher32". The "vlen-utf8" filter is supported
through
[zarr_codec_vlenutf8](https://r-cf.github.io/zarr/reference/zarr_codec_vlenutf8.md).

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_filter`

## Active bindings

- `encoded_type`:

  (read-only) The
  [zarr_data_type](https://r-cf.github.io/zarr/reference/zarr_data_type.md)
  of the encoded data, or `NULL` if the filter does not change the data
  type. This is the data type that the "bytes" codec must deserialize.

## Methods

### Public methods

- [`zarr_filter$new()`](#method-zarr_filter-initialize)

- [`zarr_filter$copy()`](#method-zarr_filter-copy)

- [`zarr_filter$encode()`](#method-zarr_filter-encode)

Inherited methods

- [`zarr_codec$decode()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-decode)
- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### `zarr_filter$new()`

Create a new filter object.

#### Usage

    zarr_filter$new(id, configuration, from = "array", to = "array")

#### Arguments

- `id`:

  The Numcodecs identifier of the filter, such as "delta".

- `configuration`:

  A list with the configuration parameters of the filter, as found in
  the Zarr v.2 metadata but without the "id" element.

- `from, to`:

  The input and output data object for the encoding operation, either
  "array" or "bytes".

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter$copy()`

Create a new, independent copy of this filter.

#### Usage

    zarr_filter$copy()

#### Returns

An instance of the same class as this filter.

------------------------------------------------------------------------

### `zarr_filter$encode()`

Filters can only decode data: Zarr v.2 stores are read-only.

#### Usage

    zarr_filter$encode(data)

#### Arguments

- `data`:

  Ignored.

#### Returns

This method always throws an error.
