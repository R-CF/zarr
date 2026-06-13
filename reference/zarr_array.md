# Zarr Array

This class implements a Zarr array. A Zarr array is stored in a node in
the hierarchy of a Zarr data set. The array contains the data for an
object.

## Super class

[`zarr_node`](https://r-cf.github.io/zarr/reference/zarr_node.md) -\>
`zarr_array`

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

Inherited methods

- [`zarr_node$append_array_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-append_array_attribute)
- [`zarr_node$delete_attributes()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-delete_attributes)
- [`zarr_node$print_attributes()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-print_attributes)
- [`zarr_node$save()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-save)
- [`zarr_node$set_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-set_attribute)

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
  instance to persist data in.

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
  range of indices along the dimension to write. If missing or `NULL`,
  the entire array will be read.

#### Returns

A vector, matrix or array of data.

------------------------------------------------------------------------

### `zarr_array$write()`

Write data for the array. The data will be chunked, encoded and
persisted in the store that the array is using. Prior to writing, any
`NA` values are assigned the `fill_value` of the `data_type` of the Zarr
array. Note that the logical type cannot encode `NA` in Zarr and any
`NA` values are set to `FALSE`.

#### Usage

    zarr_array$write(data, selection)

#### Arguments

- `data`:

  An R vector, matrix or array with the data to write. The data in the R
  object has to agree with the data type of the array.

- `selection`:

  A list as long as the array has dimensions where each element is a
  range of indices along the dimension to write. If missing, the entire
  `data` object will be written.

#### Returns

Self, invisibly.
