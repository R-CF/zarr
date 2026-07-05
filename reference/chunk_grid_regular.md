# Chunk management

This class implements the regular chunk grid for Zarr arrays. It manages
reading from and writing to Zarr stores, using the codecs for data
transformation.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`chunking`](https://r-cf.github.io/zarr/reference/chunking.md) -\>
`chunk_grid_regular`

## Active bindings

- `codecs`:

  The list of codecs used by the chunking scheme. These are set by the
  array when starting to use chunking for file I/O. Upon reading, the
  list of registered codecs.

## Methods

### Public methods

- [`chunk_grid_regular$new()`](#method-chunk_grid_regular-initialize)

- [`chunk_grid_regular$print()`](#method-chunk_grid_regular-print)

- [`chunk_grid_regular$metadata_fragment()`](#method-chunk_grid_regular-metadata_fragment)

- [`chunk_grid_regular$read()`](#method-chunk_grid_regular-read)

- [`chunk_grid_regular$write()`](#method-chunk_grid_regular-write)

------------------------------------------------------------------------

### `chunk_grid_regular$new()`

Initialize a new chunking scheme for an array.

#### Usage

    chunk_grid_regular$new(array_shape, chunk_shape)

#### Arguments

- `array_shape`:

  Integer vector of the array dimensions. This may be `NA` for a scalar
  array.

- `chunk_shape`:

  Optional. Integer vector of the dimensions of each chunk. If omitted,
  the optimal chunking is automatically determined. Ignored for a scalar
  array.

#### Returns

An instance of `chunk_grid_regular`.

------------------------------------------------------------------------

### `chunk_grid_regular$print()`

Print a short description of this chunking scheme to the console.

#### Usage

    chunk_grid_regular$print()

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `chunk_grid_regular$metadata_fragment()`

Return the metadata fragment that describes this chunking scheme.

#### Usage

    chunk_grid_regular$metadata_fragment()

#### Returns

A list with the metadata of this chunking scheme.

------------------------------------------------------------------------

### `chunk_grid_regular$read()`

Read data from the Zarr array into an R object. The read can span
multiple chunks. Reads will be parallelised if
`future::plan(multisession)` is set; by default the reading is
sequential.

#### Usage

    chunk_grid_regular$read(start, stop)

#### Arguments

- `start, stop`:

  Integer vectors of the same length as the dimensionality of the Zarr
  array, indicating the starting and ending (inclusive) indices of the
  data along each axis. These are ignored if the Zarr array is a scalar.

#### Returns

A vector, matrix or array of data.

------------------------------------------------------------------------

### `chunk_grid_regular$write()`

Write data to the array. Writing data always uses a sequential plan.

#### Usage

    chunk_grid_regular$write(data, start, stop)

#### Arguments

- `data`:

  An R object with the same dimensionality as the Zarr array.

- `start, stop`:

  Integer vectors of the same length as the dimensionality of the Zarr
  array, indicating the starting and ending (inclusive) indices of the
  data along each axis.

#### Returns

Self, invisibly.
