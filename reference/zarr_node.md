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

  The parent of the node. For a root node this returns `NULL`, otherwise
  this `zarr_group` or `zarr_array` instance. CAUTION: Setting the
  parent of a node can invalidate the Zarr hierarchy - expert use only.

- `store`:

  (read-only) The store of the node.

- `path`:

  (read-only) The path of this node, relative to the root node of the
  hierarchy.

- `prefix`:

  (read-only) The prefix of this node, relative to the root node of the
  hierarchy.

- `metadata`:

  The metadata document of this node, a `list`. CAUTION: Setting a list
  that is not properly describing this object will render the object
  invalid.

- `attributes`:

  (read-only) Retrieve the list of attributes of this object. Attributes
  can be added or modified with the `set_attribute()` method or removed
  with the `delete_attributes()` method.

## Methods

### Public methods

- [`zarr_node$new()`](#method-zarr_node-initialize)

- [`zarr_node$post_open()`](#method-zarr_node-post_open)

- [`zarr_node$print_attributes()`](#method-zarr_node-print_attributes)

- [`zarr_node$attribute()`](#method-zarr_node-attribute)

- [`zarr_node$set_attribute()`](#method-zarr_node-set_attribute)

- [`zarr_node$append_array_attribute()`](#method-zarr_node-append_array_attribute)

- [`zarr_node$delete_attribute()`](#method-zarr_node-delete_attribute)

- [`zarr_node$save()`](#method-zarr_node-save)

------------------------------------------------------------------------

### `zarr_node$new()`

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

### `zarr_node$post_open()`

This method is called automatically after a Zarr store is opened to
allow for operations after the full hierarchy has been established. This
is a no-op here, descendant classes with specific requirements should
implement this method.

#### Usage

    zarr_node$post_open()

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_node$print_attributes()`

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

### `zarr_node$attribute()`

Retrieve a specific attribute by path.

#### Usage

    zarr_node$attribute(name)

#### Arguments

- `name`:

  The name (path) of the attribute to retrieve, using `/` as separator
  for nested attributes. Numeric path segments index into array
  attributes (1-based), e.g. `"zarr_conventions/2/name"` retrieves the
  `name` field of the second convention object.

#### Returns

The attribute value, or `NULL` if not found.

------------------------------------------------------------------------

### `zarr_node$set_attribute()`

Add an attribute to the metadata of the object. If an attribute `name`
already exists, it will be overwritten.

#### Usage

    zarr_node$set_attribute(name, value)

#### Arguments

- `name`:

  The name of the attribute. The name may be a compound path, relative
  to the "attributes" entry in the metadata, using a slash "/" as path
  separator. Each of the elements in the path (between slashes) must
  begin with a letter and be composed of letters, digits, and
  underscores and can be at most 255 characters long. Missing path
  elements will be created.

- `value`:

  The value of the attribute. This can be of any supported type,
  including a vector or list of values. In general, an attribute should
  be a character value, a numeric value, a logical value, or a short
  vector or list of any of these.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_node$append_array_attribute()`

Append an attribute to an array in the metadata of the object. If an
attribute `name` already exists, it will be overwritten.

#### Usage

    zarr_node$append_array_attribute(name, value, after = NULL)

#### Arguments

- `name`:

  The name of the attribute. The name may be a compound path, relative
  to the "attributes" entry in the metadata, using a slash "/" as path
  separator. Each of the elements in the path (between slashes) must
  begin with a letter and be composed of letters, digits, and
  underscores and can be at most 255 characters long. Missing path
  elements will be created.

- `value`:

  The value of the attribute. This can be of any supported type,
  including a vector or list of values. In general, an attribute should
  be a character value, a numeric value, a logical value, or a short
  vector or list of any of these.

- `after`:

  A subscript, after which `value` is to be appended. The default is
  `NULL`, meaning that `value` will be placed after the existing values.
  Specifying `after = 0L` will place `value` before the existing values.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_node$delete_attribute()`

Delete an attribute or array element. If the attribute is not present,
this method simply returns.

#### Usage

    zarr_node$delete_attribute(name)

#### Arguments

- `name`:

  Character. The name (path) of the attribute to delete, using `/` as
  separator for nested attributes, e.g. `"first/second/my_att"`. The
  `name` is relative to the `attributes` entry in the metadata of the
  node. To target an element of a JSON array attribute, append the
  1-based index as the path segment, e.g. `"first/second/my_arr/2"` to
  delete the second element in the array, or
  `"first/second/my_arr/2/description"` to delete only the `description`
  field inside it. This nesting can be arbitrarily deep, including over
  multiple JSON arrays.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_node$save()`

Persist any edits to the group or array to the store.

#### Usage

    zarr_node$save()
