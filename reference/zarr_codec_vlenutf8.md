# Zarr vlen-utf8 codec

The Zarr "vlen-utf8" codec encodes an R character object to a raw byte
string, and decodes a raw byte string to a R character object. The
character object, typically a vector but possibly a matrix or array,
should use UTF-8 encoding, which is the standard on modern platforms
running R.

This codec is not part of the Zarr v.3 core specification but a commonly
used codec to serialize character strings into Zarr chunks. It is
defined for Zarr v.2. This implementation enables the use of the Zarr
v.3 registered `"string"` data type, as well as Zarr v.2 `"|O"` data
type.

The codec does not handle `NA` values. On encoding, `NA` values become
empty strings (`""`); on decoding empty strings are preserved (not set
to `NA`). This behaviour is adopted from Python, making it the most
interoperable arrangement. If support for `NA` values is needed at the
application level, use should be made of a sentinel character string
(like `"NO_DATA"`) which then gets set to `NA` in the application. This
will obviously not be interoperable, at least not outside of the
application ecosystem.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_vlenutf8`

## Methods

### Public methods

- [`zarr_codec_vlenutf8$new()`](#method-zarr_codec_vlenutf8-initialize)

- [`zarr_codec_vlenutf8$copy()`](#method-zarr_codec_vlenutf8-copy)

- [`zarr_codec_vlenutf8$metadata_fragment()`](#method-zarr_codec_vlenutf8-metadata_fragment)

- [`zarr_codec_vlenutf8$encode()`](#method-zarr_codec_vlenutf8-encode)

- [`zarr_codec_vlenutf8$decode()`](#method-zarr_codec_vlenutf8-decode)

Inherited methods

- [`zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### `zarr_codec_vlenutf8$new()`

Create a new "vlen-utf8" codec object.

#### Usage

    zarr_codec_vlenutf8$new()

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_codec_vlenutf8$copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_vlenutf8$copy()

#### Returns

An instance of `zarr_codec_vlenutf8`.

------------------------------------------------------------------------

### `zarr_codec_vlenutf8$metadata_fragment()`

Return the metadata fragment that describes this codec.

#### Usage

    zarr_codec_vlenutf8$metadata_fragment()

#### Returns

A list with the metadata of this codec, just the name.

------------------------------------------------------------------------

### `zarr_codec_vlenutf8$encode()`

This method writes an R character object to a raw vector. Prior to
writing, any `NA` values are converted to an empty string.

#### Usage

    zarr_codec_vlenutf8$encode(data)

#### Arguments

- `data`:

  The data to be encoded.

#### Returns

A raw vector with the encoded data object.

------------------------------------------------------------------------

### `zarr_codec_vlenutf8$decode()`

This method takes a raw vector and converts it to an R character object.

#### Usage

    zarr_codec_vlenutf8$decode(data)

#### Arguments

- `data`:

  The data to be decoded.

#### Returns

An R character object with the shape of a chunk from the array.
