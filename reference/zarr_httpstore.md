# Zarr Store for HTTP access

This class implements a Zarr HTTP store. With this class Zarr stores on
web servers can be read. For Zarr v.2 HTTP stores there exists a
standard for publishing arrays on the store, using consolidated
metadata. This class will look for such metadata in the root of the
store. If no consolidated metadata is found then a regular group or
array is searched for. Note that if a group is found that there is no
standard process to determine what arrays are available in the store and
where they are located relative to the root. Typically such information
is found in the attributes of the group and you are advised to inspect
those attributes and refer to the documentation of the store publisher.

This class performs no sanity checks on any of the arguments passed to
the methods, for performance reasons. Since this class should be
accessed through group and array objects, it is up to that code to
ensure that arguments are valid, in particular keys and prefixes.

## Super class

[`zarr::zarr_store`](https://r-cf.github.io/zarr/reference/zarr_store.md)
-\> `zarr_httpstore`

## Active bindings

- `friendlyClassName`:

  (read-only) Name of the class for printing.

- `root`:

  (read-only) The root of the HTTP store, identical to its URL.

- `uri`:

  (read-only) The URI of the store location.

- `separator`:

  (read-only) The default chunk separator of the store, usually a slash
  '/'.

## Methods

### Public methods

- [`zarr_httpstore$new()`](#method-zarr_httpstore-new)

- [`zarr_httpstore$exists()`](#method-zarr_httpstore-exists)

- [`zarr_httpstore$clear()`](#method-zarr_httpstore-clear)

- [`zarr_httpstore$erase()`](#method-zarr_httpstore-erase)

- [`zarr_httpstore$erase_prefix()`](#method-zarr_httpstore-erase_prefix)

- [`zarr_httpstore$list_dir()`](#method-zarr_httpstore-list_dir)

- [`zarr_httpstore$list_prefix()`](#method-zarr_httpstore-list_prefix)

- [`zarr_httpstore$set()`](#method-zarr_httpstore-set)

- [`zarr_httpstore$set_if_not_exists()`](#method-zarr_httpstore-set_if_not_exists)

- [`zarr_httpstore$get()`](#method-zarr_httpstore-get)

- [`zarr_httpstore$get_metadata()`](#method-zarr_httpstore-get_metadata)

- [`zarr_httpstore$set_metadata()`](#method-zarr_httpstore-set_metadata)

- [`zarr_httpstore$is_group()`](#method-zarr_httpstore-is_group)

- [`zarr_httpstore$create_group()`](#method-zarr_httpstore-create_group)

- [`zarr_httpstore$create_array()`](#method-zarr_httpstore-create_array)

Inherited methods

- [`zarr::zarr_store$getsize()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-getsize)
- [`zarr::zarr_store$getsize_prefix()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-getsize_prefix)
- [`zarr::zarr_store$is_empty()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-is_empty)
- [`zarr::zarr_store$list()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-list)

------------------------------------------------------------------------

### Method `new()`

Create an instance of this class.

HTTP stores are read-only. Currently two types of Zarr store can be
accessed. A Zarr v.2 consolidated metadata file at the root of the store
(immediately below the URL) can identify a hierarchy of groups and
arrays. Alternatively, a store with a group or a single array, either
v.2 or v.3.

#### Usage

    zarr_httpstore$new(url)

#### Arguments

- `url`:

  The path to the HTTP store to be opened. The URL may use UTF-8 code
  points.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method [`exists()`](https://rdrr.io/r/base/exists.html)

Check if a key exists in the store. The key can point to a group, an
array, or a metadata file. This check is only relevant for HTTP stores
with consolidated metadata. In other cases the single group or array
will be at the root.

#### Usage

    zarr_httpstore$exists(key)

#### Arguments

- `key`:

  Character string. The key that the store will be searched for.

#### Returns

`TRUE` if argument `key` is found, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `clear()`

Clearing the store is not supported.

#### Usage

    zarr_httpstore$clear()

#### Returns

`FALSE`.

------------------------------------------------------------------------

### Method `erase()`

Removing a key from the store is not supported.

#### Usage

    zarr_httpstore$erase(key)

#### Arguments

- `key`:

  Ignored.

#### Returns

`FALSE`.

------------------------------------------------------------------------

### Method `erase_prefix()`

Removing keys from the store is not supported.

#### Usage

    zarr_httpstore$erase_prefix(prefix)

#### Arguments

- `prefix`:

  Ignored.

#### Returns

`FALSE`.

------------------------------------------------------------------------

### Method `list_dir()`

Retrieve all keys and prefixes with a given prefix and which do not
contain the character "/" after the given prefix. In other words, this
retrieves all the nodes in the store below the node indicated by the
prefix.

#### Usage

    zarr_httpstore$list_dir(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose nodes to list.

#### Returns

A character array with all keys found in the store immediately below the
`prefix`, both for groups and arrays.

------------------------------------------------------------------------

### Method `list_prefix()`

Retrieve all keys and prefixes with a given prefix.

#### Usage

    zarr_httpstore$list_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose nodes to list.

#### Returns

A character vector with all paths found in the store below the `prefix`
location, both for groups and arrays.

------------------------------------------------------------------------

### Method `set()`

Storing a `(key, value)` pair is not supported.

#### Usage

    zarr_httpstore$set(key, value)

#### Arguments

- `key`:

  Ignored.

- `value`:

  Ignored.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `set_if_not_exists()`

Storing a `(key, value)` pair is not supported.

#### Usage

    zarr_httpstore$set_if_not_exists(key, value)

#### Arguments

- `key`:

  Ignored.

- `value`:

  Ignored.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method [`get()`](https://rdrr.io/r/base/get.html)

Retrieve the value associated with a given key.

#### Usage

    zarr_httpstore$get(key, prototype = NULL, byte_range = NULL)

#### Arguments

- `key`:

  Character string. The key for which to get data.

- `prototype`:

  Ignored. The only buffer type that is supported maps directly to an R
  raw vector.

- `byte_range`:

  Ignored. The full data value is always returned.

#### Returns

A raw vector with the data pointed at by the key.

------------------------------------------------------------------------

### Method `get_metadata()`

Retrieve the metadata document of the node at the location indicated by
the `prefix` argument. The metadata will always be presented to the
caller in the Zarr v.3 format. Attributes, if present, will be added.

#### Usage

    zarr_httpstore$get_metadata(prefix)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to retrieve.

#### Returns

A list with the metadata, or `NULL` if the prefix is not pointing to a
Zarr group or array.

------------------------------------------------------------------------

### Method `set_metadata()`

Setting metadata is not supported.

#### Usage

    zarr_httpstore$set_metadata(prefix, metadata)

#### Arguments

- `prefix`:

  Ignored.

- `metadata`:

  Ignored.

#### Returns

Self, invisible

------------------------------------------------------------------------

### Method `is_group()`

Test if `path` is pointing to a Zarr group.

#### Usage

    zarr_httpstore$is_group(path)

#### Arguments

- `path`:

  The path to test.

#### Returns

`TRUE` if the `path` points to a Zarr group, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `create_group()`

Creating a new group in the store is not supported.

#### Usage

    zarr_httpstore$create_group(path, name)

#### Arguments

- `path, name`:

  Ignored.

#### Returns

An error indicating that the group could not be created.

------------------------------------------------------------------------

### Method `create_array()`

Creating a new array in the store is not supported.

#### Usage

    zarr_httpstore$create_array(parent, name, metadata)

#### Arguments

- `parent, name, metadata`:

  Ignored.

#### Returns

An error indicating that the array could not be created.
