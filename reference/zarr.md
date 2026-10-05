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

## Active bindings

- `version`:

  (read-only) The version of the Zarr object.

- `root`:

  The root node of the Zarr object, usually a
  [zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md)
  instance but it could also be a
  [zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md)
  instance. CAUTION: When setting the root node, the entire existing
  hierarchy is deleted. The hierarchy will likely be out of sync with
  the store after setting the root node.

- `store`:

  (read-only) The store of the Zarr object.

- `domain`:

  (read-only) The `zarr_domain` instance managing the data in this
  `zarr` object.

- `groups`:

  (read-only) Retrieve the paths to the groups of the Zarr object,
  starting from the root group, as a character vector.

- `arrays`:

  (read-only) Retrieve the paths to the arrays of the Zarr object,
  starting from the root group, as a character vector.

## Methods

### Public methods

- [`zarr$new()`](#method-zarr-initialize)

- [`zarr$print()`](#method-zarr-print)

- [`zarr$hierarchy()`](#method-zarr-hierarchy)

- [`zarr$get_node()`](#method-zarr-get_node)

- [`zarr$add_group()`](#method-zarr-add_group)

- [`zarr$add_array()`](#method-zarr-add_array)

- [`zarr$delete_group()`](#method-zarr-delete_group)

- [`zarr$delete_array()`](#method-zarr-delete_array)

- [`zarr$clone()`](#method-zarr-clone)

------------------------------------------------------------------------

### `zarr$new()`

Create a new Zarr instance. The Zarr instance manages the groups and
arrays in the Zarr store that it refers to. This instance provides
access to all objects in the Zarr store.

This method can open any Zarr store located on systems with a supported
protocol ('local', 's3', 'http').

This method can also create a new Zarr store on a local file system or
in memory. It is not possible to create a new store on S3 or an a web
server. The newly created store is uninitialised, it is an empty
directory. Either assign a
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md) to the
`root` field, or create a root
[zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md) to
make the store valid and usable.

#### Usage

    zarr$new(store, read_only = NULL, protocol = NULL, ...)

#### Arguments

- `store`:

  Optional. Either an instance of a
  [zarr_store](https://r-cf.github.io/zarr/reference/zarr_store.md)
  descendant class where the Zarr objects are located, or character
  string that indicates a location on a file system or a HTTP or S3
  server where the Zarr store is to be found. The character string may
  contain UTF-8 characters and/or use a file URI format. On a local file
  system the Zarr store will be created if it does not exist. If
  omitted, an in-memory Zarr store will be created.

- `read_only`:

  Optional. Logical that indicates if the store is to be opened in
  read-only mode. Default is ` NULL`, which implies `FALSE` for a local
  file system and memory store, `TRUE` otherwise.

- `protocol`:

  Optional, character string. Override automatic protocol detection
  ('local', 'http', or 's3'). Needed for S3-compatible endpoints that
  aren't AWS and don't follow AWS's hostname conventions (MinIO, EMBASSY
  Cloud, Ceph RGW, etc.) - there's no reliable way to recognize these
  from the URL alone, you have to indicate so explicitly rather than
  have this method parse the location.

- `...`:

  Additional protocol-specific parameters passed through to the
  underlying store constructor. For `s3://` and S3 `https://` locations,
  this includes `region`, `profile`, `access_key`/`secret_key`/
  `session_token`, `endpoint`, and `anonymous` — see
  [zarr_s3store](https://r-cf.github.io/zarr/reference/zarr_s3store.md).
  Ignored for memory, local and plain HTTP locations.

#### Returns

A `zarr` object.

------------------------------------------------------------------------

### `zarr$print()`

Print a summary of the Zarr object to the console.

#### Usage

    zarr$print()

------------------------------------------------------------------------

### `zarr$hierarchy()`

Print the Zarr hierarchy to the console.

#### Usage

    zarr$hierarchy()

------------------------------------------------------------------------

### `zarr$get_node()`

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

### `zarr$add_group()`

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

### `zarr$add_array()`

Add an array in a group with a given path.

#### Usage

    zarr$add_array(path, name, metadata)

#### Arguments

- `path`:

  The path to the group of the new array, a single character string.

- `name`:

  The name for the new array, a single character string.

- `metadata`:

  A `list` with the metadata for the new array, or a valid
  [array_builder](https://r-cf.github.io/zarr/reference/array_builder.md)
  instance.

#### Returns

The newly created
[zarr_array](https://r-cf.github.io/zarr/reference/zarr_array.md), or
`NULL` if the array could not be created.

------------------------------------------------------------------------

### `zarr$delete_group()`

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

### `zarr$delete_array()`

Delete an array from the Zarr object. If the array is the root of the
Zarr object, the Zarr object will become uninitialised. **Warning:**
this operation is irreversible for many stores!

#### Usage

    zarr$delete_array(path)

#### Arguments

- `path`:

  The path to the array.

#### Returns

Self, invisible.

------------------------------------------------------------------------

### `zarr$clone()`

The objects of this class are cloneable with this method.

#### Usage

    zarr$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
