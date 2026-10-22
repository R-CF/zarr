# Chunk management

This class implements the basic ancestor for chunking the data of Zarr
arrays. It provides the mechanism for chunk access in the Zarr store
that is independent of the geometry of the chunk grid: addressing chunks
by their grid index through the chunk key encoding, caching chunk I/O
objects, raw chunk access and relocating chunks in the store.

The geometry of the chunk grid - how the array is partitioned into
chunks along each dimension - is the responsibility of descendant
classes. The "regular" chunk grid that is a required component of Zarr
v.3 is implemented by the `chunk_grid_regular` class. Zarr arrays that
use sharding are managed by the `chunk_grid_sharded` class, a descendant
of `chunk_grid_regular` because the sharding codec requires a regular
grid of shards. Sharding is treated as a chunking scheme rather than as
a codec because it has to do the same topological operations as a
regular chunk manager to map a user request for data to ranges across
multiple chunks (and shards) and then apply the set of codecs that
apply. These codecs for sharded data are embedded in the sharding
configuration.

A descendant class must set the private field `.grid` and implement the
private method `max_chunk_length()` and the public methods `resize()`,
`read()` and, if supported,
[`write()`](https://rdrr.io/r/base/write.html).

There is no point instantiating this class directly, other than in the
`initialize()` method of a descendant class.

## Super class

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> `chunking`

## Active bindings

- `array_shape`:

  (read-only) The shape of the array, `NULL` for a scalar array.

- `grid`:

  (read-only) The number of chunks along each dimension of the array.
  This is an empty integer vector for a scalar array.

- `chunk_encoding`:

  Set or retrieve the chunk key encoding to be used for creating store
  keys for chunks.

- `data_type`:

  The data type of the array using the chunking scheme. This is set by
  the array when starting to use chunking for file I/O.

- `store`:

  The store of the array using the chunking scheme. This is set by the
  array when starting to use chunking for file I/O.

- `array_prefix`:

  The prefix of the array using the chunking scheme. This is set by the
  array when starting to use chunking for file I/O.

## Methods

### Public methods

- [`chunking$new()`](#method-chunking-initialize)

- [`chunking$resize()`](#method-chunking-resize)

- [`chunking$insert_dimension()`](#method-chunking-insert_dimension)

- [`chunking$chunk_keys()`](#method-chunking-chunk_keys)

- [`chunking$read_raw()`](#method-chunking-read_raw)

- [`chunking$write_raw()`](#method-chunking-write_raw)

- [`chunking$flush()`](#method-chunking-flush)

Inherited methods

- [`zarr_extension$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_extension.html#method-metadata_fragment)

------------------------------------------------------------------------

### `chunking$new()`

Initialize a new chunking scheme for an array. This should only be
called by descendant classes, which must also set the grid of chunks of
a non-scalar array.

#### Usage

    chunking$new(class_name, array_shape)

#### Arguments

- `class_name`:

  Character string given the name of the chunking scheme.

- `array_shape`:

  Integer vector of the array dimensions. This may be `NA` for a scalar
  array.

#### Returns

An instance of `chunking`.

------------------------------------------------------------------------

### `chunking$resize()`

Resize the array by growing or shrinking any combination of dimensions
at either end, updating the chunks in the store accordingly. How a
requested change maps onto the chunk grid is determined by the
descendant class.

#### Usage

    chunking$resize(low, high)

#### Arguments

- `low, high`:

  Integer vectors, one element per array dimension, with the requested
  change in extent at the low and high end of each dimension. Positive
  grows that end, negative shrinks it.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `chunking$insert_dimension()`

Move the chunks in the store to the grid of an array whose rank is one
higher, by inserting a new dimension that holds exactly one chunk. A
scalar array has its single chunk moved to the first chunk of a rank-1
grid. Chunk payload is never touched. The chunking scheme itself is not
updated: the caller must create a new chunking scheme for the promoted
array.

#### Usage

    chunking$insert_dimension(dimension)

#### Arguments

- `dimension`:

  Integer, the 1-based position of the new dimension in the grid of the
  promoted array.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `chunking$chunk_keys()`

Generate the keys of all chunks in the chunk grid, or of all shards for
a sharded array. Keys are derived from the grid and the chunk key
encoding, not by listing the store, so this works for stores that cannot
list their keys. Chunks need not exist in the store.

#### Usage

    chunking$chunk_keys()

#### Returns

A character vector of chunk keys, relative to the array prefix.

------------------------------------------------------------------------

### `chunking$read_raw()`

Read the bytes of a chunk (or shard) as they are held in the store,
without decoding. Any pending edits to the chunk are flushed to the
store first.

#### Usage

    chunking$read_raw(key)

#### Arguments

- `key`:

  Chunk key relative to the array prefix, as produced by `chunk_keys()`.

#### Returns

A raw vector, or `NULL` if the chunk is not present in the store.

------------------------------------------------------------------------

### `chunking$write_raw()`

Write the bytes of a chunk (or shard) to the store, without encoding.
Any cached copy of the chunk is dropped. The caller is responsible for
`value` being consistent with the codecs of the array.

#### Usage

    chunking$write_raw(key, value)

#### Arguments

- `key`:

  Chunk key relative to the array prefix, as produced by `chunk_keys()`.

- `value`:

  A raw vector with the encoded chunk.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `chunking$flush()`

Persist the data in all chunks with pending edits to the store. This
base implementation is a no-op for chunking schemes that do not buffer
writes.

#### Usage

    chunking$flush()

#### Returns

Self, invisibly.
