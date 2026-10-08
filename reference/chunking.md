# Chunk management

This class implements the basic ancestor for chunking the data of Zarr
arrays. It provides the basic scaffolding chunk and shard access in the
Zarr store and stores objects for topology operations on the chunk grid
of the array.

Descendant classes implement specific chunking schemes. Apart from the
"regular" chunking that is a required component of Zarr v.3, implemented
through the `chunk_grid_regular` class, Zarr arrays that use sharding
are also treated as a chunk manager, the `chunk_grid_sharded` class,
even though sharding is a codec in the Zarr v.3 specification. The
reason for this is that the sharding "codec" has to do the same
topological operations as a regular chunk manager to map a user request
for data to ranges across multiple chunks (and shards) and then apply
the set of codecs that apply. These codecs for sharded data are embedded
in the sharding configuration.

There is no point instantiating this class directly, other than in the
`initialize()` method of a descendant class.

## Super class

[`zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> `chunking`

## Active bindings

- `chunk_shape`:

  (read-only) The dimensions of each chunk in the chunk grid of the
  associated array.

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

- [`chunking$chunk_keys()`](#method-chunking-chunk_keys)

- [`chunking$read_raw()`](#method-chunking-read_raw)

- [`chunking$write_raw()`](#method-chunking-write_raw)

- [`chunking$flush()`](#method-chunking-flush)

Inherited methods

- [`zarr_extension$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_extension.html#method-metadata_fragment)

------------------------------------------------------------------------

### `chunking$new()`

Initialize a new chunking scheme for an array. This should only be
called by descendant classes.

#### Usage

    chunking$new(class_name, array_shape, chunk_shape)

#### Arguments

- `class_name`:

  Character string given the name of the chunking scheme.

- `array_shape`:

  Integer vector of the array dimensions. This may be `NA` for a scalar
  array.

- `chunk_shape`:

  Integer vector of the dimensions of each chunk (or shard). Ignored for
  a scalar array.

#### Returns

An instance of `chunking`.

------------------------------------------------------------------------

### `chunking$resize()`

Physically resize the on-disk chunk grid: rename chunks whose grid index
moved, delete chunks that fell entirely outside the new shape, and `NA`
the excess tail of a chunk left partly outside a shrinking,
non-chunk-aligned high boundary. No chunk payload is re-encoded except
for that trailing clip.

#### Usage

    chunking$resize(new_shape, shift, high)

#### Arguments

- `new_shape`:

  Integer vector, the array's new shape.

- `shift`:

  Integer vector, whole chunks by which the origin moves per dimension
  (positive = grew at the low end, negative = shrank).

- `high`:

  Integer vector, the requested high-end element deltas (used only to
  decide which boundary chunks need NA-clipping).

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
