# Zarr codecs

Zarr codecs encode data from the user data to stored data, using one or
more transformations, such as compression. Decoding of stored data is
the inverse process, whereby the codecs are applied in reverse order.

## Super class

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> `zarr_codec`

## Active bindings

- `mode`:

  (read-only) Retrieve the operating mode of the encoding operation of
  the codec in form of a string "array -\> array", "array -\> bytes" or
  "bytes -\> bytes".

- `from`:

  (read-only) Character string that indicates the source data type of
  this codec, either "array" or "bytes".

- `to`:

  (read-only) Character string that indicates the output data type of
  this codec, either "array" or "bytes".

- `configuration`:

  (read-only) A list with the configuration parameters of the codec,
  exactly like they are defined in Zarr. This field is read-only but
  each codec class has fields to set individual parameters.

## Methods

### Public methods

- [`zarr_codec$new()`](#method-zarr_codec-new)

- [`zarr_codec$copy()`](#method-zarr_codec-copy)

- [`zarr_codec$print()`](#method-zarr_codec-print)

- [`zarr_codec$metadata_fragment()`](#method-zarr_codec-metadata_fragment)

- [`zarr_codec$encode()`](#method-zarr_codec-encode)

- [`zarr_codec$decode()`](#method-zarr_codec-decode)

------------------------------------------------------------------------

### Method `new()`

Create a new codec object.

#### Usage

    zarr_codec$new(name, configuration)

#### Arguments

- `name`:

  The name of the codec, a single character string.

- `configuration`:

  A list with the configuration parameters for this codec.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec$copy()

#### Returns

This method always throws an error.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a summary of the codec to the console.

#### Usage

    zarr_codec$print()

------------------------------------------------------------------------

### Method `metadata_fragment()`

Return the metadata fragment that describes this codec.

#### Usage

    zarr_codec$metadata_fragment()

#### Returns

A list with the metadata of this codec.

------------------------------------------------------------------------

### Method `encode()`

This method encodes a data object but since this is the base codec class
the "encoding" is a no-op.

#### Usage

    zarr_codec$encode(data)

#### Arguments

- `data`:

  The data to be encoded.

#### Returns

The encoded data object, unaltered.

------------------------------------------------------------------------

### Method `decode()`

This method decodes a data object but since this is the base codec class
the "decoding" is a no-op.

#### Usage

    zarr_codec$decode(data)

#### Arguments

- `data`:

  The data to be decoded.

#### Returns

The decoded data object, unaltered.
