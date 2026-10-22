# Chunk management

This class implements the regular chunk grid for Zarr arrays, in which
all chunks have the same shape. Chunks along the high end of a dimension
extend beyond the array when the array shape is not a multiple of the
chunk shape. It manages reading from and writing to Zarr stores, using
the codecs for data transformation.

## Super classes

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> [`chunking`](https://r-cf.github.io/zarr/reference/chunking.md) -\>
`chunk_grid_regular`

## Active bindings

- `chunk_shape`:

  (read-only) The dimensions of each chunk in the chunk grid of the
  associated array.

- `codecs`:

  The list of codecs used by the chunking scheme. These are set by the
  array when starting to use chunking for file I/O. Upon reading, the
  list of registered codecs.

## Methods

### Public methods

- [`chunk_grid_regular$new()`](#method-chunk_grid_regular-initialize)

- [`chunk_grid_regular$print()`](#method-chunk_grid_regular-print)

- [`chunk_grid_regular$metadata_fragment()`](#method-chunk_grid_regular-metadata_fragment)

- [`chunk_grid_regular$resize()`](#method-chunk_grid_regular-resize)

- [`chunk_grid_regular$read()`](#method-chunk_grid_regular-read)

- [`chunk_grid_regular$write()`](#method-chunk_grid_regular-write)

- [`chunk_grid_regular$flush()`](#method-chunk_grid_regular-flush)

Inherited methods

- [`chunking$chunk_keys()`](https://r-cf.github.io/zarr/reference/chunking.html#method-chunk_keys)
- [`chunking$insert_dimension()`](https://r-cf.github.io/zarr/reference/chunking.html#method-insert_dimension)
- [`chunking$read_raw()`](https://r-cf.github.io/zarr/reference/chunking.html#method-read_raw)
- [`chunking$write_raw()`](https://r-cf.github.io/zarr/reference/chunking.html#method-write_raw)

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

### `chunk_grid_regular$resize()`

Resize the array, growing or shrinking any combination of dimensions at
either end in one pass. Chunks are renamed in the store when their grid
index moves and erased when they fall outside the new grid. No chunk
payload is re-encoded except for a chunk left straddling a shrinking,
non-chunk-aligned high-end boundary, whose excess elements are set to
the fill value.

Because chunks have a fixed position on the grid, `low` can only move in
whole chunks: values are rounded outward to the nearest chunk (more
space added when growing, less removed when shrinking). `high` is not
constrained this way.

#### Usage

    chunk_grid_regular$resize(low, high)

#### Arguments

- `low, high`:

  Integer vectors, one element per array dimension. Positive grows that
  end, negative shrinks it, `0` leaves it unchanged.

#### Details

An error is thrown when the resize would produce a non-positive extent
along any dimension, or when the array would shrink to a high boundary
that is not aligned to the chunk boundary while the chunking scheme
cannot clip chunks.

#### Returns

Self, invisibly.

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

    chunk_grid_regular$write(data, start, stop, flush = TRUE)

#### Arguments

- `data`:

  An R object with the same dimensionality as the Zarr array.

- `start, stop`:

  Integer vectors of the same length as the dimensionality of the Zarr
  array, indicating the starting and ending (inclusive) indices of the
  data along each axis. Ignored for a scalar array.

- `flush`:

  Logical, default is `TRUE`. Should the chunks that have been written
  to be flushed to the store (`TRUE`), or should they be left stale for
  further writes to the same chunk (`FALSE`). Leaving the chunks stale
  for further writing leads to better performance when chunks are
  written to multiple times. Call the
  [`flush()`](https://rdrr.io/r/base/connections.html) method to persist
  data in stale chunks.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `chunk_grid_regular$flush()`

Persist the data in all chunks with pending edits to the store.

#### Usage

    chunk_grid_regular$flush()
