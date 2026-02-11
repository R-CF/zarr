# Zarr object

This class implements a Zarr object. A Zarr object is a set of objects
that make up an instance of a Zarr data set, irrespective of where it is
located. The Zarr object manages the hierarchy as well as the underlying
store.

A Zarr object may contain multiple Zarr arrays in a hierarchy. The main
class for managing Zarr arrays is
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md). The
hierarchy is made up of
[zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md)
instances. Each `zarr_array` is located in a `zarr_group`.

## Value

A `zarr` object.

## Active bindings

- `version`:

  (read-only) The version of the Zarr object.

- `root`:

  (read-only) The root node of the Zarr object, usually a
  [zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md)
  instance but it could also be a
  [zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
  instance.

- `store`:

  (read-only) The store of the Zarr object.

- `groups`:

  (read-only) Retrieve the paths to the groups of the Zarr object,
  starting from the root group, as a character vector.

- `arrays`:

  (read-only) Retrieve the paths to the arrays of the Zarr object,
  starting from the root group, as a character vector.

## Methods

### Public methods

- [`zarr$new()`](#method-zarr-new)

- [`zarr$print()`](#method-zarr-print)

- [`zarr$hierarchy()`](#method-zarr-hierarchy)

- [`zarr$get_node()`](#method-zarr-get_node)

- [`zarr$add_group()`](#method-zarr-add_group)

- [`zarr$add_array()`](#method-zarr-add_array)

- [`zarr$delete_group()`](#method-zarr-delete_group)

- [`zarr$delete_array()`](#method-zarr-delete_array)

- [`zarr$clone()`](#method-zarr-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new Zarr instance. The Zarr instance manages the groups and
arrays in the Zarr store that it refers to. This instance provides
access to all objects in the Zarr store.

#### Usage

    zarr$new(store)

#### Arguments

- `store`:

  An instance of a
  [zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md)
  descendant class where the Zarr objects are located.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a summary of the Zarr object to the console.

#### Usage

    zarr$print()

------------------------------------------------------------------------

### Method `hierarchy()`

Print the Zarr hierarchy to the console.

#### Usage

    zarr$hierarchy()

------------------------------------------------------------------------

### Method `get_node()`

Retrieve the group or array represented by the node located at the path.

#### Usage

    zarr$get_node(path)

#### Arguments

- `path`:

  The path to the node to retrieve. Must start with a forward-slash "/".

#### Returns

The [zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md) or
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
instance located at `path`, or `NULL` if the `path` was not found.

------------------------------------------------------------------------

### Method `add_group()`

Add a group below a given path.

#### Usage

    zarr$add_group(path, name)

#### Arguments

- `path`:

  The path to the parent group of the new group, a single character
  string.

- `name`:

  The name for the new group, a single character string.

#### Returns

The newly created
[zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md), or
`NULL` if the group could not be created.

------------------------------------------------------------------------

### Method `add_array()`

Add an array in a group with a given path.

#### Usage

    zarr$add_array(path, name, metadata)

#### Arguments

- `path`:

  The path to the group of the new array, a single character string.

- `name`:

  The name for the new array, a single character string.

- `metadata`:

  A `list` with the metadata for the new array.

#### Returns

The newly created
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md), or
`NULL` if the array could not be created.

------------------------------------------------------------------------

### Method `delete_group()`

Delete a group from the Zarr object. This will also delete the group
from the Zarr store. The root group cannot be deleted but it can be
specified through `path = "/"` in which case the root group loses any
specific group metadata (with only the basic parameters remaining), as
well as any arrays and sub-groups if `recursive = TRUE`. **Warning:**
this operation is irreversible for many stores!

#### Usage

    zarr$delete_group(path, recursive = FALSE)

#### Arguments

- `path`:

  The path to the group.

- `recursive`:

  Logical, default `FALSE`. If `FALSE`, the operation will fail if the
  group has any arrays or sub-groups. If `TRUE`, the group and all Zarr
  objects contained by it will be deleted.

#### Returns

Self, invisible.

------------------------------------------------------------------------

### Method `delete_array()`

Delete an array from the Zarr object. If the array is the root of the
Zarr object, it will be converted into a regular Zarr object with a root
group. **Warning:** this operation is irreversible for many stores!

#### Usage

    zarr$delete_array(path)

#### Arguments

- `path`:

  The path to the array.

#### Returns

Self, invisible.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    zarr$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
