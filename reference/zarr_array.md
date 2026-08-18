# Zarr Array

This class implements a Zarr array. A Zarr array is stored in a node in
the hierarchy of a Zarr data set. The array contains the data for an
object.

## Super classes

[`zarr_object`](https://r-cf.github.io/zarr/reference/zarr_object.md)
-\> [`zarr_node`](https://r-cf.github.io/zarr/reference/zarr_node.md)
-\> `zarr_array`

## Active bindings

- `data_type`:

  (read-only) Retrieve the data type of the array.

- `shape`:

  (read-only) Retrieve the shape of the array, an integer vector.

- `chunking`:

  (read-only) The chunking engine for this array.

- `chunk_separator`:

  (read-only) Retrieve the separator to be used for creating store keys
  for chunks.

- `codecs`:

  The list of codecs that this array uses for encoding data (and
  decoding in inverse order).

## Methods

### Public methods

- [`zarr_array$new()`](#method-zarr_array-initialize)

- [`zarr_array$print()`](#method-zarr_array-print)

- [`zarr_array$hierarchy_nodes()`](#method-zarr_array-hierarchy_nodes)

- [`zarr_array$read()`](#method-zarr_array-read)

- [`zarr_array$write()`](#method-zarr_array-write)

- [`zarr_array$resize()`](#method-zarr_array-resize)

- [`zarr_array$promote()`](#method-zarr_array-promote)

Inherited methods

- [`zarr_object$print_attributes()`](https://r-cf.github.io/zarr/reference/zarr_object.html#method-print_attributes)
- [`zarr_node$absolute_path()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-absolute_path)
- [`zarr_node$append_array_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-append_array_attribute)
- [`zarr_node$attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-attribute)
- [`zarr_node$delete_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-delete_attribute)
- [`zarr_node$post_open()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-post_open)
- [`zarr_node$relative_path()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-relative_path)
- [`zarr_node$save()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-save)
- [`zarr_node$set_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-set_attribute)
- [`zarr_node$walk_path()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-walk_path)

------------------------------------------------------------------------

### `zarr_array$new()`

Initialize a new array in a Zarr hierarchy. The array must already exist
in the store

#### Usage

    zarr_array$new(name, metadata, parent, store)

#### Arguments

- `name`:

  The name of the array.

- `metadata`:

  List with the metadata of the array.

- `parent`:

  The parent `zarr_group` instance of this new array, can be missing or
  `NULL` if the Zarr object should have just this array.

- `store`:

  The [zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md)
  instance to persist data in. Ignored if `parent` is specified.

#### Returns

An instance of `zarr_array`.

------------------------------------------------------------------------

### `zarr_array$print()`

Print a summary of the array to the console.

#### Usage

    zarr_array$print()

------------------------------------------------------------------------

### `zarr_array$hierarchy_nodes()`

Prints the hierarchy of this array to a character string. Usually called
from the Zarr object or a group to display the full group hierarchy.

#### Usage

    zarr_array$hierarchy_nodes(idx, total)

#### Arguments

- `idx, total`:

  Arguments to control indentation.

------------------------------------------------------------------------

### `zarr_array$read()`

Read some or all of the array data for the array. For all types other
than logical, any data elements with the `fill_value` of the Zarr data
type are set to `NA`.

#### Usage

    zarr_array$read(selection)

#### Arguments

- `selection`:

  A list as long as the array has dimensions where each element is a
  range of indices along the dimension to read. If missing or `NULL`,
  the entire array will be read.

#### Returns

A vector, matrix or array of data.

------------------------------------------------------------------------

### `zarr_array$write()`

Write data for the array. The data will be chunked, encoded and
persisted in the store that the array is using. Prior to writing, any
`NA` values are assigned the `fill_value` of the array. Note that the
logical type cannot encode `NA` in Zarr and any `NA` values are set to
`FALSE`.

#### Usage

    zarr_array$write(data, selection)

#### Arguments

- `data`:

  An R vector, matrix or array with the data to write. The data in the R
  object has to agree with the data type and rank of the array.

- `selection`:

  Optional. A `list` as long as the array has dimensions where each
  element is a range of indices along the dimension to write. If
  missing, the `data` object must have the same size as the array.
  Ignored when the array is scalar.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_array$resize()`

Resize the array, growing or shrinking any combination of dimensions at
either end in one pass. Existing chunk payload is never rewritten,
except for a chunk left straddling a shrinking, non-chunk- aligned
high-end boundary (its excess elements become `NA`).

Because the chunk grid is fixed, `low` can only move in whole chunks:
values are rounded outward to the nearest chunk (more space added when
growing, less removed when shrinking), so the array's origin may land
ahead of where the actual data starts; those cells read as `NA`. `high`
is not constrained this way.

#### Usage

    zarr_array$resize(low, high)

#### Arguments

- `low, high`:

  Integer vectors, one element per array dimension. Positive grows that
  end, negative shrinks it, `0` (default) leaves it unchanged.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_array$promote()`

Insert a new dimension into the array, increasing its rank by one. This
operation doesn't grow an existing dimension, it creates one where there
wasn't one before — the typical case being promoting a 0-d scalar array
to rank 1, or giving an existing array a new leading dimension (e.g.
turning a `(lat, lon)` array into a `(time, lat, lon)` array once a
second file/time step becomes available).

Existing chunk payload is moved, never re-encoded: inserting a
size-`length` dimension whose chunk size equals `length` never changes
the relative order of elements in the encoded byte stream, for any array
rank or transpose order, because a size-1-chunk dimension never
contributes more than a single (vacuous) index to the enumeration. So
every existing chunk is just renamed with a "0" grid index inserted at
`dimension`. The new dimension therefore always starts out as exactly
one full chunk; grow it afterwards with `resize()`.

#### Usage

    zarr_array$promote(dimension, length = 1L)

#### Arguments

- `dimension`:

  Integer. 1-based position of the new dimension in the resulting shape;
  `1` prepends it, `rank + 1` appends it.

- `length`:

  The size of the new dimension, and also its chunk size. Default `1L`.

#### Returns

Self, invisibly.
