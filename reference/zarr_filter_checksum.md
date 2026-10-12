# Zarr v.2 checksum filters

The "crc32", "adler32" and "fletcher32" filters add a 32-bit checksum to
the data, in little-endian byte order. The "crc32" and "adler32"
checksums are placed at the start of the data unless the configuration
has a `location` of "end"; the "fletcher32" checksum is always placed at
the end. Decoding strips the checksum and verifies it against the data:
if the two don't match a warning is generated.

The "fletcher32" checksum is the HDF5 variant. The two 16-bit sums are
verified modulo 65535 because the HDF5 algorithm does not reduce a sum
of 65535 to 0.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\>
[`zarr_filter`](https://r-cf.github.io/zarr/reference/zarr_filter.md)
-\> `zarr_filter_checksum`

## Methods

### Public methods

- [`zarr_filter_checksum$new()`](#method-zarr_filter_checksum-initialize)

- [`zarr_filter_checksum$decode()`](#method-zarr_filter_checksum-decode)

Inherited methods

- [`zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)
- [`zarr_filter$copy()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-copy)
- [`zarr_filter$encode()`](https://r-cf.github.io/zarr/reference/zarr_filter.html#method-encode)

------------------------------------------------------------------------

### `zarr_filter_checksum$new()`

Create a new checksum filter.

#### Usage

    zarr_filter_checksum$new(id, configuration = list())

#### Arguments

- `id`:

  The Numcodecs identifier of the filter, one of "crc32", "adler32" or
  "fletcher32".

- `configuration`:

  A list with the configuration parameters of the filter, optionally
  with element `location` for "crc32" and "adler32".

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_filter_checksum$decode()`

Strip the checksum from the data and verify it.

#### Usage

    zarr_filter_checksum$decode(data)

#### Arguments

- `data`:

  The encoded data, a raw vector.

#### Returns

A raw vector with the decoded data.
