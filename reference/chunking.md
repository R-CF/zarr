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

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
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

- [`chunking$new()`](#method-chunking-new)

Inherited methods

- [`zarr::zarr_extension$metadata_fragment()`](https://r-cf.github.io/zarr/reference/zarr_extension.html#method-metadata_fragment)

------------------------------------------------------------------------

### Method `new()`

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
