# Zarr bytes codec

The Zarr "bytes" codec encodes an R data object to a raw byte string,
and decodes a raw byte string to a R object, possibly inverting the
endianness of the data in the operation.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_bytes`

## Active bindings

- `endian`:

  Set or retrieve the endianness of the storage of the data with this
  codec. A string with value of "big" or "little".

## Methods

### Public methods

- [`zarr_codec_bytes$new()`](#method-zarr_codec_bytes-new)

- [`zarr_codec_bytes$copy()`](#method-zarr_codec_bytes-copy)

- [`zarr_codec_bytes$metadata_fragment()`](#method-zarr_codec_bytes-metadata_fragment)

- [`zarr_codec_bytes$encode()`](#method-zarr_codec_bytes-encode)

- [`zarr_codec_bytes$decode()`](#method-zarr_codec_bytes-decode)

Inherited methods

- [`zarr::zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### Method `new()`

Create a new "bytes" codec object.

#### Usage

    zarr_codec_bytes$new(data_type, chunk_shape, configuration = NULL)

#### Arguments

- `data_type`:

  The
  [zarr_data_type](https://r-cf.github.io/zarr/reference/zarr_data_type.md)
  instance of the Zarr array that this codec is used for.

- `chunk_shape`:

  The shape of a chunk of data of the array, an integer vector.

- `configuration`:

  Optional. A list with the configuration parameters for this codec. The
  element `endian` specifies the byte ordering of the data type of the
  Zarr array. A string with value "big" or "little". If not given, the
  default endianness of the platform is used.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_bytes$copy()

#### Returns

An instance of `zarr_codec_bytes`.

------------------------------------------------------------------------

### Method `metadata_fragment()`

Return the metadata fragment that describes this codec.

#### Usage

    zarr_codec_bytes$metadata_fragment()

#### Returns

A list with the metadata of this codec.

------------------------------------------------------------------------

### Method `encode()`

This method writes an R object to a raw vector in the data type of the
Zarr array. Prior to writing, any `NA` values are assigned the
`fill_value` of the `data_type` of the Zarr array. Note that the logical
type cannot encode `NA` in Zarr and any `NA` values are set to `FALSE`.

#### Usage

    zarr_codec_bytes$encode(data)

#### Arguments

- `data`:

  The data to be encoded.

#### Returns

A raw vector with the encoded data object.

------------------------------------------------------------------------

### Method `decode()`

This method takes a raw vector and converts it to an R object of an
appropriate type. For all types other than logical, any data elements
with the `fill_value` of the Zarr data type are set to `NA`.

#### Usage

    zarr_codec_bytes$decode(data)

#### Arguments

- `data`:

  The data to be decoded.

#### Returns

An R object with the shape of a chunk from the array.
