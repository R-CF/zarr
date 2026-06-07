# Numpy UCS-4 codec

The Numpy UCS-4 format is a fixed-length character string format where
shorter string are padded on the right with 0's. This is not a Zarr
codec but specific to Numpy. It is included here because many Zarr v.2
stores have been written with this formatting of character strings.
Since it does not use a codec in Zarr v.2, it is an invalid
configuration in Zarr v.3 and this package because it embodies the
`array -> bytes` step that is mandatory in Zarr v.3 - this is why this
mock codec is included. This "codec" encodes an R character object to a
raw byte string, and decodes a raw byte string to a R character object.
The character object, typically a vector but possibly a matrix or array,
should use UTF-8 encoding, which is the standard on modern platforms
running R.

This codec is not part of the Zarr v.3 core specification but a commonly
used process in Zarr v.2 on Python to serialize character strings into
Zarr chunks. This implementation enables the use of the Zarr v.2 `"<U*"`
data type. As a consequence, this codec can only decode data - new data
is not written in this format.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_ucs4`

## Active bindings

- `endian`:

  (read-only) Retrieve the endianness of the storage of the data with
  this codec. A string with value of "big" or "little".

## Methods

### Public methods

- [`zarr_codec_ucs4$new()`](#method-zarr_codec_ucs4-initialize)

- [`zarr_codec_ucs4$copy()`](#method-zarr_codec_ucs4-copy)

- [`zarr_codec_ucs4$metadata_fragment()`](#method-zarr_codec_ucs4-metadata_fragment)

- [`zarr_codec_ucs4$decode()`](#method-zarr_codec_ucs4-decode)

Inherited methods

- [`zarr_codec$encode()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-encode)
- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### `zarr_codec_ucs4$new()`

Create a new UCS-4 codec object.

#### Usage

    zarr_codec_ucs4$new(chunk_shape, configuration)

#### Arguments

- `chunk_shape`:

  The shape of a chunk of data of the array, an integer vector.

- `configuration`:

  A list with the configuration parameters for this codec. This is a
  list created in this package, it does not exist in the Zarr store as
  the Numpy UCS-4 method is not a real codec. The element `endian`
  specifies the byte ordering of the data type of the Zarr array. A
  string with value "big" or "little". The element `width` given the
  fixed padded string width.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_codec_ucs4$copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_ucs4$copy()

#### Returns

An instance of `zarr_codec_ucs4`.

------------------------------------------------------------------------

### `zarr_codec_ucs4$metadata_fragment()`

Return the metadata fragment that describes this codec.

#### Usage

    zarr_codec_ucs4$metadata_fragment()

#### Returns

A list with the metadata of this codec, just the name.

------------------------------------------------------------------------

### `zarr_codec_ucs4$decode()`

This method takes a raw UCS-4 vector and converts it to an R character
object.

#### Usage

    zarr_codec_ucs4$decode(data)

#### Arguments

- `data`:

  The data to be decoded.

#### Returns

An R character object with the shape of a chunk from the array.
