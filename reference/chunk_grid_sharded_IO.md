# Reader class for sharded arrays

Process the data of an individual shard file. This class reads the shard
index and decodes inner chunks on demand, caching decoded inner chunks
to avoid redundant I/O and decoding on overlapping selections. Inner
chunks needed for a given read are fetched in a single coalesced
byte-range request covering all required inner chunks, minimising the
number of store requests — particularly important for HTTP stores.

## Methods

### Public methods

- [`chunk_grid_sharded_IO$new()`](#method-chunk_grid_sharded_IO-new)

- [`chunk_grid_sharded_IO$read()`](#method-chunk_grid_sharded_IO-read)

------------------------------------------------------------------------

### Method `new()`

Create a new IO handler for a single shard.

#### Usage

    chunk_grid_sharded_IO$new(
      key,
      shard_shape,
      inner_shape,
      inner_codecs,
      index_codecs,
      index_loc,
      dtype,
      store
    )

#### Arguments

- `key`:

  Store key for this shard file.

- `shard_shape`:

  Integer vector, the shape of this shard.

- `inner_shape`:

  Integer vector, the shape of each inner chunk.

- `inner_codecs`:

  List of
  [zarr_codec](https://r-cf.github.io/zarr/reference/zarr_codec.md)
  instances for inner chunks.

- `index_codecs`:

  List of
  [zarr_codec](https://r-cf.github.io/zarr/reference/zarr_codec.md)
  instances for the index.

- `index_loc`:

  Character, `"end"` or `"start"`.

- `dtype`:

  A
  [zarr_data_type](https://r-cf.github.io/zarr/reference/zarr_data_type.md)
  instance.

- `store`:

  A [zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md)
  instance.

------------------------------------------------------------------------

### Method `read()`

Read a region from this shard.

Inner chunks needed for this read are fetched in a single coalesced
byte-range request. Previously decoded inner chunks are served from
cache without any store access.

#### Usage

    chunk_grid_sharded_IO$read(offset, length)

#### Arguments

- `offset`:

  Integer vector of 0-based offsets into the shard.

- `length`:

  Integer vector of lengths along each dimension.

#### Returns

An array of decoded data.
