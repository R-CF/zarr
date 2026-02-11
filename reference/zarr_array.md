# Zarr Array

This class implements a Zarr array. A Zarr array is stored in a node in
the hierarchy of a Zarr data set. The array contains the data for an
object.

## Super class

[`zarr::zarr_node`](https://r-cf.github.io/zarr/reference/zarr_node.md)
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

- [`zarr_array$new()`](#method-zarr_array-new)

- [`zarr_array$print()`](#method-zarr_array-print)

- [`zarr_array$hierarchy()`](#method-zarr_array-hierarchy)

- [`zarr_array$read()`](#method-zarr_array-read)

- [`zarr_array$write()`](#method-zarr_array-write)

Inherited methods

- [`zarr::zarr_node$delete_attributes()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-delete_attributes)
- [`zarr::zarr_node$print_attributes()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-print_attributes)
- [`zarr::zarr_node$save()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-save)
- [`zarr::zarr_node$set_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-set_attribute)

------------------------------------------------------------------------

### Method `new()`

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

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a summary of the array to the console.

#### Usage

    zarr_array$print()

------------------------------------------------------------------------

### Method `hierarchy()`

Prints the hierarchy of the groups and arrays to the console. Usually
called from the Zarr object or its root group to display the full group
hierarchy.

#### Usage

    zarr_array$hierarchy(idx, total)

#### Arguments

- `idx, total`:

  Arguments to control indentation.

------------------------------------------------------------------------

### Method `read()`

Read some or all of the array data for the array.

#### Usage

    zarr_array$read(selection)

#### Arguments

- `selection`:

  A list as long as the array has dimensions where each element is a
  range of indices along the dimension to write. If missing, the entire
  array will be read.

#### Returns

A vector, matrix or array of data.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write data for the array. The data will be chunked, encoded and
persisted in the store that the array is using.

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
