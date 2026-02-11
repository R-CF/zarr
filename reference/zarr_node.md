# Zarr Hierarchy node

This class implements a Zarr node. The node is an element in the
hierarchy of the Zarr object. As per the Zarr specification, the node is
either a group or an array. Thus, this class is the ancestor of the
[zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md) and
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
classes. This class manages common features such as names, key, prefixes
and paths, as well as the hierarchy between nodes and the
[zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md) for
persistent storage.

This class should never have to be instantiated or accessed directly.
Instead, use instances of `zarr_group` or `zarr_array`. Function
arguments are largely not checked, the group and array instances should
do so prior to calling methods here. The big exception is checking the
validity of node names.

## Active bindings

- `name`:

  (read-only) The name of the node.

- `parent`:

  (read-only) The parent of the node. For a root node this returns
  `NULL`, otherwise this `zarr_group` or `zarr_array` instance.

- `store`:

  (read-only) The store of the node.

- `path`:

  (read-only) The path of this node, relative to the root node of the
  hierarchy.

- `prefix`:

  (read-only) The prefix of this node, relative to the root node of the
  hierarchy.

- `metadata`:

  (read-only) The metadata document of this node, a list.

- `attributes`:

  (read-only) Retrieve the list of attributes of this object. Attributes
  can be added or modified with the `set_attribute()` method or removed
  with the `delete_attributes()` method.

## Methods

### Public methods

- [`zarr_node$new()`](#method-zarr_node-new)

- [`zarr_node$print_attributes()`](#method-zarr_node-print_attributes)

- [`zarr_node$set_attribute()`](#method-zarr_node-set_attribute)

- [`zarr_node$delete_attributes()`](#method-zarr_node-delete_attributes)

- [`zarr_node$save()`](#method-zarr_node-save)

------------------------------------------------------------------------

### Method `new()`

Initialize a new node in a Zarr hierarchy.

#### Usage

    zarr_node$new(name, metadata, parent, store)

#### Arguments

- `name`:

  The name of the node.

- `metadata`:

  List with the metadata of the node.

- `parent`:

  The parent node of this new node. Must be omitted when initializing a
  root node.

- `store`:

  The store to persist data in. Ignored if a `parent` is specified.

------------------------------------------------------------------------

### Method `print_attributes()`

Print the metadata "attributes" to the console. Usually called by the
[zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md) and
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
[`print()`](https://rdrr.io/r/base/print.html) methods.

#### Usage

    zarr_node$print_attributes(...)

#### Arguments

- `...`:

  Arguments passed to embedded functions. Of particular interest is
  `width = .` to specify the maximum width of the columns.

------------------------------------------------------------------------

### Method `set_attribute()`

Add an attribute to the metadata of the object. If an attribute `name`
already exists, it will be overwritten.

#### Usage

    zarr_node$set_attribute(name, value)

#### Arguments

- `name`:

  The name of the attribute. The name must begin with a letter and be
  composed of letters, digits, and underscores, with a maximum length of
  255 characters.

- `value`:

  The value of the attribute. This can be of any supported type,
  including a vector or list of values. In general, an attribute should
  be a character value, a numeric value, a logical value, or a short
  vector or list of any of these.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `delete_attributes()`

Delete attributes. If an attribute in `name` is not present this method
simply returns.

#### Usage

    zarr_node$delete_attributes(name)

#### Arguments

- `name`:

  Vector of names of the attributes to delete.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method [`save()`](https://rdrr.io/r/base/save.html)

Persist any edits to the group or array to the store.

#### Usage

    zarr_node$save()
