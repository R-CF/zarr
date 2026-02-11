# Reader / Writer class for regular chunked arrays

Process the data of an individual chunk on a regular grid. This class
will read the chunk from the store and decode it (as necessary), then
merge the new data with it, encode the updated chunk and write back to
the store.

## Methods

### Public methods

- [`chunk_grid_regular_IO$new()`](#method-chunk_grid_regular_IO-new)

- [`chunk_grid_regular_IO$read()`](#method-chunk_grid_regular_IO-read)

- [`chunk_grid_regular_IO$write()`](#method-chunk_grid_regular_IO-write)

- [`chunk_grid_regular_IO$flush()`](#method-chunk_grid_regular_IO-flush)

------------------------------------------------------------------------

### Method `new()`

Create a new instance of this class.

#### Usage

    chunk_grid_regular_IO$new(key, chunk_shape, dtype, store, codecs)

#### Arguments

- `key`:

  The key of the chunk in the store.

- `chunk_shape`:

  Integer vector with the shape of the chunk.

- `dtype`:

  The
  [zarr_data_type](https://r-cf.github.io/zarr/reference/zarr_data_type.md)
  of the array.

- `store`:

  The [zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md)
  instance that is the store of this array.

- `codecs`:

  List of
  [zarr_codec](https://r-cf.github.io/zarr/reference/zarr_codec.md)
  instances to use. The list will be copied such that this chunk
  reader/writer can be run asynchronously.

------------------------------------------------------------------------

### Method `read()`

Read some data from the chunk.

#### Usage

    chunk_grid_regular_IO$read(offset, length)

#### Arguments

- `offset, length`:

  The integer offsets and length that determine where from the chunk to
  read the data.

#### Returns

The requested data, as an R object with dimensions set when it is a
matrix or array.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write some data to the chunk.

#### Usage

    chunk_grid_regular_IO$write(data, offset, flush = FALSE)

#### Arguments

- `data`:

  The data to write to the chunk.

- `offset`:

  The integer offsets that determine where in the chunk to write the
  data. Ignored if argument `data` has a full chunk of data.

- `flush`:

  If `TRUE`, the chunk will be written to file iimediately after writing
  the new data to it. If `FALSE`, data will be written to the chunk but
  not persisted to the store - this is more efficient when writing
  multiple slabs of data to a chunk.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method [`flush()`](https://rdrr.io/r/base/connections.html)

If the chunk has changed applied to it, persist the chunk to the store.

#### Usage

    chunk_grid_regular_IO$flush()

#### Returns

Self, invisibly.
