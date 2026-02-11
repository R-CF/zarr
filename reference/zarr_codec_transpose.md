# Zarr transpose codec

The Zarr "transpose" codec registers the storage order of a data object
relative to the canonical row-major ordering of Zarr. If the registered
ordering is different from the native ordering on the platform where the
array is being read, the data object will be permuted upon reading.

R data is arranged in column-major order. The most efficient storage
arrangement between Zarr and R is thus column-major ordering, avoiding
encoding to the canonical row-major ordering during storage and decoding
to column-major ordering during a read. If the storage arrangement is
not row-major ordering, a transpose codec must be added to the array
definition. Note that within R, both writing and reading are no-ops when
data is stored in column-major ordering. On the other hand, when no
transpose codec is defined for the array, there will be an automatic
transpose of the data on writing and reading to maintain compatibility
with the Zarr specification. Using the
[array_builder](https://r-cf.github.io/zarr/reference/array_builder.md)
will automatically add the transpose codec to the array definition.

For maximum portability (e.g. with Zarr implementations outside of R
that do not implement the transpose codec), data should be stored in
row-major order, which can be achieved by not including this codec in
the array definition.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::zarr_codec`](https://r-cf.github.io/zarr/reference/zarr_codec.md)
-\> `zarr_codec_transpose`

## Active bindings

- `order`:

  Set or retrieve the 0-based ordering of the dimensions of the array
  when storing

## Methods

### Public methods

- [`zarr_codec_transpose$new()`](#method-zarr_codec_transpose-new)

- [`zarr_codec_transpose$copy()`](#method-zarr_codec_transpose-copy)

- [`zarr_codec_transpose$encode()`](#method-zarr_codec_transpose-encode)

- [`zarr_codec_transpose$decode()`](#method-zarr_codec_transpose-decode)

Inherited methods

- [`zarr::zarr_codec$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-metadata_fragment)
- [`zarr::zarr_codec$print()`](https://r-cf.github.io/zarr/reference/zarr_codec.html#method-print)

------------------------------------------------------------------------

### Method `new()`

Create a new "transpose" codec object.

#### Usage

    zarr_codec_transpose$new(shape_length, configuration = list())

#### Arguments

- `shape_length`:

  The length of the shape of the array that this codec operates on.

- `configuration`:

  Optional. A list with the configuration parameters for this codec. The
  element `order` specifies the ordering of the dimensions of the shape
  relative to the Zarr canonical arrangement. An integer vector with a
  length equal to argument `shape_length`. The ordering must be 0-based.
  If not given, the default R ordering is used.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `copy()`

Create a new, independent copy of this codec.

#### Usage

    zarr_codec_transpose$copy()

#### Returns

An instance of `zarr_codec_transpose`.

------------------------------------------------------------------------

### Method `encode()`

This method permutes a data object to match the desired dimension
ordering.

#### Usage

    zarr_codec_transpose$encode(data)

#### Arguments

- `data`:

  The data to be permuted, an R matrix or array.

#### Returns

The permuted data object, a matrix or array in Zarr store dimension
order.

------------------------------------------------------------------------

### Method `decode()`

This method permutes a data object from a Zarr store to an R matrix or
array.

#### Usage

    zarr_codec_transpose$decode(data)

#### Arguments

- `data`:

  The data to be permuted, from a Zarr store.

#### Returns

The permuted data object, an R matrix or array.
