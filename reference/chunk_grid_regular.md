# Chunk management

This class implements the regular chunk grid for Zarr arrays. It manages
reading from and writing to Zarr stores, using the codecs for data
transformation.

## Super class

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> `chunk_grid_regular`

## Active bindings

- `chunk_shape`:

  (read-only) The dimensions of each chunk in the chunk grid of the
  associated array.

- `chunk_grid`:

  (read-only) The chunk grid of the associated array, i.e. the number of
  chunks in each dimension.

- `chunk_encoding`:

  Set or retrieve the chunk key encoding to be used for creating store
  keys for chunks.

- `data_type`:

  The data type of the array using the chunking scheme. This is set by
  the array when starting to use chunking for file I/O.

- `codecs`:

  The list of codecs used by the chunking scheme. These are set by the
  array when starting to use chunking for file I/O. Upon reading, the
  list of registered codecs.

- `store`:

  The store of the array using the chunking scheme. This is set by the
  array when starting to use chunking for file I/O.

- `array_prefix`:

  The prefix of the array using the chunking scheme. This is set by the
  array when starting to use chunking for file I/O.

## Methods

### Public methods

- [`chunk_grid_regular$new()`](#method-chunk_grid_regular-new)

- [`chunk_grid_regular$print()`](#method-chunk_grid_regular-print)

- [`chunk_grid_regular$metadata_fragment()`](#method-chunk_grid_regular-metadata_fragment)

- [`chunk_grid_regular$read()`](#method-chunk_grid_regular-read)

- [`chunk_grid_regular$write()`](#method-chunk_grid_regular-write)

------------------------------------------------------------------------

### Method `new()`

Initialize a new chunking scheme for an array.

#### Usage

    chunk_grid_regular$new(array_shape, chunk_shape)

#### Arguments

- `array_shape`:

  Integer vector of the array dimensions.

- `chunk_shape`:

  Integer vector of the dimensions of each chunk.

#### Returns

An instance of `chunk_grid_regular`.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a short description of this chunking scheme to the console.

#### Usage

    chunk_grid_regular$print()

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `metadata_fragment()`

Return the metadata fragment that describes this chunking scheme.

#### Usage

    chunk_grid_regular$metadata_fragment()

#### Returns

A list with the metadata of this codec.

------------------------------------------------------------------------

### Method `read()`

Read data from the Zarr array into an R object.

#### Usage

    chunk_grid_regular$read(start, stop)

#### Arguments

- `start, stop`:

  Integer vectors of the same length as the dimensionality of the Zarr
  array, indicating the starting and ending (inclusive) indices of the
  data along each axis.

#### Returns

A vector, matrix or array of data.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write data to the array.

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
