# Sharding chunk management

This class implements the sharded chunk grid for Zarr arrays. It manages
reading from Zarr stores, using the codecs for data transformation
included in the sharding configuration. Writing is not supported with
this codec. Storing a scalar array in a sharded grid is not possible
either and totally useless anyway.

## Super classes

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\>
[`zarr::chunking`](https://r-cf.github.io/zarr/reference/chunking.md)
-\> `chunk_grid_sharded`

## Active bindings

- `inner_shape`:

  (read-only) The dimensions of each chunk in the shard.

- `codecs`:

  (read-only) The list of codecs used by the sharding scheme.

- `index_codecs`:

  (read-only) The list of codecs used by the sharding scheme for the
  indexing of the internal chunks.

## Methods

### Public methods

- [`chunk_grid_sharded$new()`](#method-chunk_grid_sharded-new)

- [`chunk_grid_sharded$print()`](#method-chunk_grid_sharded-print)

- [`chunk_grid_sharded$metadata_fragment()`](#method-chunk_grid_sharded-metadata_fragment)

- [`chunk_grid_sharded$read()`](#method-chunk_grid_sharded-read)

------------------------------------------------------------------------

### Method `new()`

Initialize a new sharded chunking scheme for an array.

#### Usage

    chunk_grid_sharded$new(
      array_shape,
      chunk_shape,
      inner_shape,
      index_loc,
      inner_codecs,
      index_codecs
    )

#### Arguments

- `array_shape`:

  Integer vector of the array dimensions.

- `chunk_shape`:

  Integer vector of the dimensions of each outer chunk, i.e. the size of
  a shard.

- `inner_shape`:

  Integer vector of the dimensions of each inner chunk, i.e. the size of
  a single chunk inside a shard.

- `index_loc`:

  Location of the shard index in the shard file, either "start" or
  "end".

- `inner_codecs, index_codecs`:

  List of `zarr_codec` instances to decode the inner chunks and the
  index, respectively.

#### Returns

An instance of `chunk_grid_sharded`.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a short description of this sharded chunking scheme to the
console.

#### Usage

    chunk_grid_sharded$print()

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `metadata_fragment()`

Return the metadata fragment that describes this chunking scheme.

#### Usage

    chunk_grid_sharded$metadata_fragment()

#### Returns

A list with the metadata of this chunking scheme.

------------------------------------------------------------------------

### Method `read()`

Read data from the Zarr array into an R object.

#### Usage

    chunk_grid_sharded$read(start, stop)

#### Arguments

- `start, stop`:

  Integer vectors of the same length as the dimensionality of the Zarr
  array, indicating the starting and ending (inclusive) indices of the
  data along each axis.

#### Returns

A vector, matrix or array of data.
