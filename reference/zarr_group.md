# Zarr Group

This class implements a Zarr group. A Zarr group is a node in the
hierarchy of a Zarr object. A group is a container for other groups and
arrays.

A Zarr group is identified by a JSON file having required metadata,
specifically the attribute `"node_type": "group"`.

## Super class

[`zarr::zarr_node`](https://r-cf.github.io/zarr/reference/zarr_node.md)
-\> `zarr_group`

## Active bindings

- `children`:

  (read-only) The children of the group. This is a list of `zarr_group`
  and `zarr_array` instances, or the empty list if the group has no
  children.

- `groups`:

  (read-only) Retrieve the paths to the sub-groups of the hierarchy
  starting from the current group, as a character vector.

- `arrays`:

  (read-only) Retrieve the paths to the arrays of the hierarchy starting
  from the current group, as a character vector.

## Methods

### Public methods

- [`zarr_group$new()`](#method-zarr_group-new)

- [`zarr_group$print()`](#method-zarr_group-print)

- [`zarr_group$hierarchy()`](#method-zarr_group-hierarchy)

- [`zarr_group$build_hierarchy()`](#method-zarr_group-build_hierarchy)

- [`zarr_group$get_node()`](#method-zarr_group-get_node)

- [`zarr_group$count_arrays()`](#method-zarr_group-count_arrays)

- [`zarr_group$add_group()`](#method-zarr_group-add_group)

- [`zarr_group$add_array()`](#method-zarr_group-add_array)

- [`zarr_group$delete()`](#method-zarr_group-delete)

- [`zarr_group$delete_all()`](#method-zarr_group-delete_all)

Inherited methods

- [`zarr::zarr_node$delete_attributes()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-delete_attributes)
- [`zarr::zarr_node$print_attributes()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-print_attributes)
- [`zarr::zarr_node$save()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-save)
- [`zarr::zarr_node$set_attribute()`](https://r-cf.github.io/zarr/reference/zarr_node.html#method-set_attribute)

------------------------------------------------------------------------

### Method `new()`

Open a group in a Zarr hierarchy. The group must already exist in the
store.

#### Usage

    zarr_group$new(name, metadata, parent, store)

#### Arguments

- `name`:

  The name of the group. For a root group, this is the empty string
  `""`.

- `metadata`:

  List with the metadata of the group.

- `parent`:

  The parent `zarr_group` instance of this new group, can be missing or
  `NULL` for the root group.

- `store`:

  The [zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md)
  instance to persist data in.

#### Returns

An instance of `zarr_group`.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a summary of the group to the console.

#### Usage

    zarr_group$print()

------------------------------------------------------------------------

### Method `hierarchy()`

Prints the hierarchy of the group and its subgroups and arrays to the
console. Usually called from the Zarr object or its root group to
display the full group hierarchy.

#### Usage

    zarr_group$hierarchy(idx = 1L, total = 1L)

#### Arguments

- `idx, total`:

  Arguments to control indentation. Should both be 1 (the default) when
  called interactively. The values will be updated during recursion when
  there are groups below the current group.

------------------------------------------------------------------------

### Method `build_hierarchy()`

Return the hierarchy contained in the store as a tree of group and array
nodes. This method only has to be called after opening an existing Zarr
store - this is done automatically by user-facing code. After that,
users can access the `children` property of this class.

#### Usage

    zarr_group$build_hierarchy()

#### Returns

This zarr_group instance with all of its children linked.

------------------------------------------------------------------------

### Method `get_node()`

Retrieve the group or array represented by the node located at the path
relative from the current group.

#### Usage

    zarr_group$get_node(path)

#### Arguments

- `path`:

  The path to the node to retrieve. The path is relative to the group,
  it must not start with a slash "/". The path may start with any number
  of double dots ".." separated by slashes "/" to denote groups higher
  up in the hierarchy.

#### Returns

The zarr_group or
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
instance located at `path`, or `NULL` if the `path` was not found.

------------------------------------------------------------------------

### Method `count_arrays()`

Count the number of arrays in this group, optionally including arrays in
sub-groups.

#### Usage

    zarr_group$count_arrays(recursive = TRUE)

#### Arguments

- `recursive`:

  Logical flag that indicates if arrays in sub-groups should be included
  in the count. Default is `TRUE`.

------------------------------------------------------------------------

### Method `add_group()`

Add a group to the Zarr hierarchy under the current group.

#### Usage

    zarr_group$add_group(name)

#### Arguments

- `name`:

  The name of the new group.

#### Returns

The newly created `zarr_group` instance, or `NULL` if the group could
not be created.

------------------------------------------------------------------------

### Method `add_array()`

Add an array to the Zarr hierarchy in the current group.

#### Usage

    zarr_group$add_array(name, metadata)

#### Arguments

- `name`:

  The name of the new array.

- `metadata`:

  A `list` with the metadata for the new array, or an instance of class
  [array_builder](https://r-cf.github.io/zarr/reference/array_builder.md)
  whose data make a valid array definition.

#### Returns

The newly created `zarr_array` instance, or `NULL` if the array could
not be created.

------------------------------------------------------------------------

### Method `delete()`

Delete a group or an array contained by this group. When deleting a
group it cannot contain other groups or arrays. **Warning:** this
operation is irreversible for many stores!

#### Usage

    zarr_group$delete(name)

#### Arguments

- `name`:

  The name of the group or array to delete. This will also accept a path
  to a group or array but the group or array must be a node directly
  under this group.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `delete_all()`

Delete all the groups and arrays contained by this group, including any
sub-groups and arrays. Any specific metadata attached to this group is
deleted as well - only a basic metadata document is maintained.
**Warning:** this operation is irreversible for many stores!

#### Usage

    zarr_group$delete_all()

#### Returns

Self, invisibly.
