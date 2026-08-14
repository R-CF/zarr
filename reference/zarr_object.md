# Zarr base object

This class implements the common features of objects that make up Zarr.
This class is the ancestor of
[zarr_node](https://r-cf.github.io/zarr/reference/zarr_node.md) and thus
the [zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md)
and [zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
classes. This class manages common features such as names and attribute
management. This class may also be used by other descendant classes that
need a name and attributes (such as the coordinate system classes in
package `geozarr`).

The main function of this class is to manage attributes of a Zarr
object. Groups and arrays can have attributes, but other object
descending from this class may have attributes as well. In order to
accommodate the various applications, all methods dealing with
attributes take a `list` object with the attributes as the first
argument - the class has no private or public field to hold the
attributes.

This class should never have to be instantiated or accessed directly.
Instead, use instances of `zarr_group` or `zarr_array`. Function
arguments are largely not checked, the group and array instances should
do so prior to calling methods here. The big exception is checking the
validity of node names.

## Active bindings

- `name`:

  Set or retrieve the name of the Zarr object.

## Methods

### Public methods

- [`zarr_object$new()`](#method-zarr_object-initialize)

- [`zarr_object$print_attributes()`](#method-zarr_object-print_attributes)

- [`zarr_object$attribute()`](#method-zarr_object-attribute)

- [`zarr_object$set_attribute()`](#method-zarr_object-set_attribute)

- [`zarr_object$append_array_attribute()`](#method-zarr_object-append_array_attribute)

- [`zarr_object$delete_attribute()`](#method-zarr_object-delete_attribute)

- [`zarr_object$clone()`](#method-zarr_object-clone)

------------------------------------------------------------------------

### `zarr_object$new()`

Initialize a new Zarr object.

#### Usage

    zarr_object$new(name)

#### Arguments

- `name`:

  The name of the node.

------------------------------------------------------------------------

### `zarr_object$print_attributes()`

Print attributes to the console. Usually called by the
[zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md) and
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
[`print()`](https://rdrr.io/r/base/print.html) methods.

#### Usage

    zarr_object$print_attributes(dirty = FALSE, ...)

#### Arguments

- `dirty`:

  Optional. Logical flag that indicates if the attributes have unsaved
  edits. Default is `FALSE`.

- `...`:

  Arguments passed to embedded functions. Of particular interest is
  `width = .` to specify the maximum width of the columns.

#### Returns

A (multi-line) character string with the attributes of the Zarr object.

------------------------------------------------------------------------

### `zarr_object$attribute()`

Retrieve a specific attribute by path.

#### Usage

    zarr_object$attribute(atts, name)

#### Arguments

- `atts`:

  The `list` object with the attributes.

- `name`:

  The name (path) of the attribute to retrieve, using `/` as separator
  for nested attributes. Numeric path segments index into array
  attributes (1-based), e.g. `"zarr_conventions/2/name"` retrieves the
  `name` field of the second convention object.

#### Returns

The attribute value, or `NULL` if not found.

------------------------------------------------------------------------

### `zarr_object$set_attribute()`

Add an attribute to the metadata of the object. If an attribute `name`
already exists, it will be overwritten.

#### Usage

    zarr_object$set_attribute(atts, name, value)

#### Arguments

- `atts`:

  The `list` object with the attributes.

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

A `list` with the updated attributes.

------------------------------------------------------------------------

### `zarr_object$append_array_attribute()`

Append an attribute to an array in the metadata of the object. If an
attribute `name` already exists, it will be overwritten.

#### Usage

    zarr_object$append_array_attribute(atts, name, value, after = NULL)

#### Arguments

- `atts`:

  The `list` object with the attributes.

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

A `list` with the updated attributes.

------------------------------------------------------------------------

### `zarr_object$delete_attribute()`

Delete an attribute or array element. If the attribute is not present,
this method simply returns.

#### Usage

    zarr_object$delete_attribute(atts, name)

#### Arguments

- `atts`:

  The `list` object with the attributes.

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

A `list` with the updated attributes.

------------------------------------------------------------------------

### `zarr_object$clone()`

The objects of this class are cloneable with this method.

#### Usage

    zarr_object$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
