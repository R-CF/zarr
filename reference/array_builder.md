# Array builder

This class builds the metadata document for an array to be created or
modified. It can also be used to inspect the metadata document of an
existing Zarr array.

The Zarr core specification is quite complex for arrays, including
codecs and storage transformers that are part optional, part mandatory,
and dependent on each other. On top of that, extensions defined outside
of the core specification must also be handled in the same metadata
document. This class helps construct a valid metadata document, with
support for (some) extensions. (If you need support for a specific
extension, open an issue on Github.)

When creating array definitions, the default is to use R ordering,
meaning that a transpose codec is added with the "order" parameters
having the dimensions in reverse order. If you want to use a different
ordering, for instance to have a Zarr store with maximum portability,
delete the default transpose codec or set its ordering to the desired
values. Note that the shape and chunk_shape parameters are set in
reference to the ordering in the transpose codec (or the default 0, 1,
... is no transpose codec is present), but that within the R environment
the shape and chunk shape are always set to R ordering. This is
necessary to be able to apply array operations on the data in R.

This class does not care about the "chunk_key_encoding" parameter. This
is addressed at the level of the store.

The "codecs" parameter has a default first codec of "transpose". This
ensures that R matrices and arrays can be stored in native column-major
order with the store still accessible to environments that use row-major
order by default, such as Python. A second default codec is "bytes" that
records the endianness of the data. Other codecs may be added by the
user, such as a compression codec.

This class only handles the mandatory attributes in a Zarr array
metadata document. Optional arguments may be set directly on the Zarr
array after it has been created.

## Active bindings

- `format`:

  The Zarr format to build the metadata for. The value must be 3. After
  changing the format, many fields will have been reset to a default
  value.

- `portable`:

  Logical flag to indicate if the array is specified for maximum
  portability across environments (e.g. Python, Java, C++). Default is
  `FALSE`. Setting the portability to `TRUE` implies that R data will be
  permuted before writing the array to the store. A value of `FALSE` is
  therefore more efficient.

- `data_type`:

  The data type of the Zarr array. After changing the format, many
  fields will have been reset to a default value.

- `fill_value`:

  The value in the array of uninitialized data elements. The
  `fill_value` has to agree with the `data_type` of the array.

- `shape`:

  The shape of the Zarr array, an integer vector of lengths along the
  dimensions of the array. Setting the shape will reset the chunking
  settings to their default values.

- `chunk_shape`:

  The shape of each individual chunk in which to store the Zarr array.
  When setting, pass in an integer vector of lengths of the same size as
  the shape of the array. The `shape` of the array must be set before
  setting this. When reading, returns an instance of class
  [chunk_grid_regular](https://r-cf.github.io/zarr/reference/chunk_grid_regular.md).

- `codec_info`:

  (read-only) Retrieve a `data.frame` of registered codec modes and
  names for this array.

- `codecs`:

  (read-only) A list with validated and instantiated codecs for
  processing data associated with this array.

## Methods

### Public methods

- [`array_builder$new()`](#method-array_builder-new)

- [`array_builder$print()`](#method-array_builder-print)

- [`array_builder$metadata()`](#method-array_builder-metadata)

- [`array_builder$add_codec()`](#method-array_builder-add_codec)

- [`array_builder$remove_codec()`](#method-array_builder-remove_codec)

- [`array_builder$is_valid()`](#method-array_builder-is_valid)

------------------------------------------------------------------------

### Method `new()`

Create a new instance of the `array_builder` class. Optionally, a
metadata document may be passed in as an argument to inspect the
definition of an existing Zarr array, or to use as a template for a new
metadata document.

#### Usage

    array_builder$new(metadata = NULL)

#### Arguments

- `metadata`:

  Optional. A JSON metadata document or list of metadata from an
  existing Zarr array. This document will not be modified through any
  operation in this class.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print the array metadata to the console.

#### Usage

    array_builder$print()

------------------------------------------------------------------------

### Method `metadata()`

Retrieve the metadata document to create a Zarr array.

#### Usage

    array_builder$metadata(format = "list")

#### Arguments

- `format`:

  Either "list" or "JSON".

#### Returns

The metadata document in the requested format.

------------------------------------------------------------------------

### Method `add_codec()`

Adds a codec at the end of the currently registered codecs. Optionally,
the `.position` argument may be used to indicate a specific position of
the codec in the list. Codecs can only be added if their mode agrees
with the mode of existing codecs - if this codec does not agree with the
existing codecs, a warning will be issued and the new codec will not be
registered.

#### Usage

    array_builder$add_codec(codec, configuration, .position = NULL)

#### Arguments

- `codec`:

  The name of the codec. This must be a registered codec with an
  implementation that is available from this package.

- `configuration`:

  List with configuration parameters of the `codec`. May be `NULL` or
  [`list()`](https://rdrr.io/r/base/list.html) for codecs that do not
  have configuration parameters.

- `.position`:

  Optional, the 1-based position where to insert the codec in the list.
  If the number is larger than the list, the codec will be appended at
  the end of the list of codecs.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `remove_codec()`

Remove a codec from the list of codecs for the array. A codec cannot be
removed if the remaining codecs do not form a valid chain due to mode
conflicts.

#### Usage

    array_builder$remove_codec(codec)

#### Arguments

- `codec`:

  The name of the codec to remove, a single character string.

------------------------------------------------------------------------

### Method `is_valid()`

This method indicates if the current specification results in a valid
metadata document to create a Zarr array.

#### Usage

    array_builder$is_valid()

#### Returns

`TRUE` if a valid metadata document can be generated, `FALSE` otherwise.
