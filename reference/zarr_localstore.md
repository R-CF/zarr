# Zarr Store for the Local File System

This class implements a Zarr store for the local file system. With this
class Zarr stores on devices accessible through the local file system
can be read and written to. This includes locally attached drives,
removable media, NFS mounts, etc.

The chunking pattern is to locate all the chunks of an array in a single
directory. That means that chunks have names like "c0.0.0" in the array
directory.

This class performs no sanity checks on any of the arguments passed to
the methods, for performance reasons. Since this class should be
accessed through group and array objects, it is up to that code to
ensure that arguments are valid, in particular keys and prefixes.

## References

https://zarr-specs.readthedocs.io/en/latest/v3/stores/filesystem/index.html

## Super class

[`zarr::zarr_store`](https://r-cf.github.io/zarr/reference/zarr_store.md)
-\> `zarr_localstore`

## Active bindings

- `friendlyClassName`:

  (read-only) Name of the class for printing.

- `root`:

  (read-only) The root directory of the file system store.

- `uri`:

  (read-only) The URI of the store location.

- `separator`:

  (read-only) The default chunk separator of the local file store,
  usually a dot '.'.

## Methods

### Public methods

- [`zarr_localstore$new()`](#method-zarr_localstore-new)

- [`zarr_localstore$exists()`](#method-zarr_localstore-exists)

- [`zarr_localstore$clear()`](#method-zarr_localstore-clear)

- [`zarr_localstore$erase()`](#method-zarr_localstore-erase)

- [`zarr_localstore$erase_prefix()`](#method-zarr_localstore-erase_prefix)

- [`zarr_localstore$list_dir()`](#method-zarr_localstore-list_dir)

- [`zarr_localstore$list_prefix()`](#method-zarr_localstore-list_prefix)

- [`zarr_localstore$set()`](#method-zarr_localstore-set)

- [`zarr_localstore$set_if_not_exists()`](#method-zarr_localstore-set_if_not_exists)

- [`zarr_localstore$get()`](#method-zarr_localstore-get)

- [`zarr_localstore$get_metadata()`](#method-zarr_localstore-get_metadata)

- [`zarr_localstore$set_metadata()`](#method-zarr_localstore-set_metadata)

- [`zarr_localstore$is_group()`](#method-zarr_localstore-is_group)

- [`zarr_localstore$create_group()`](#method-zarr_localstore-create_group)

- [`zarr_localstore$create_array()`](#method-zarr_localstore-create_array)

Inherited methods

- [`zarr::zarr_store$getsize()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-getsize)
- [`zarr::zarr_store$getsize_prefix()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-getsize_prefix)
- [`zarr::zarr_store$is_empty()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-is_empty)
- [`zarr::zarr_store$list()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-list)

------------------------------------------------------------------------

### Method `new()`

Create an instance of this class.

If the root location does not exist, it will be created. The location on
the file system must be writable by the process creating the store. The
store is not yet functional in the sense that it is just an empty
directory. Write a root group with `.$create_group('/', '')` or an array
with `.$create_array('/', '', metadata)` for a single-array store before
any other operations on the store.

If the root location does exist on the file system it must be a valid
Zarr store, as determined by the presence of a "zarr.json" file. It is
an error to try to open a Zarr store on an existing location where this
metadata file is not present.

#### Usage

    zarr_localstore$new(root, read_only = FALSE)

#### Arguments

- `root`:

  The path to the local store to be created or opened. The path may use
  UTF-8 code points. Following the Zarr specification, it is recommended
  that the root path has an extension of ".zarr" to easily identify the
  location as a Zarr store. When creating a file store, the root
  directory cannot already exist.

- `read_only`:

  Flag to indicate if the store is opened read-only. Default `FALSE`.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method [`exists()`](https://rdrr.io/r/base/exists.html)

Check if a key exists in the store. The key can point to a group, an
array, or a chunk.

#### Usage

    zarr_localstore$exists(key)

#### Arguments

- `key`:

  Character string. The key that the store will be searched for.

#### Returns

`TRUE` if argument `key` is found, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `clear()`

Clear the store. Remove all keys and values from the store. Invoking
this method deletes affected files on the file system and this action
can not be undone. The only file that will remain is "zarr.json" or
".zgroup" (version 2) in the root of this store.

#### Usage

    zarr_localstore$clear()

#### Returns

`TRUE` if the operation proceeded, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `erase()`

Remove a key from the store. The key must point to an array chunk or an
empty group. The location of the key and all of its values are removed.

#### Usage

    zarr_localstore$erase(key)

#### Arguments

- `key`:

  Character string. The key to remove from the store.

#### Returns

`TRUE` if the operation proceeded, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `erase_prefix()`

Remove all keys in the store that begin with a given prefix. The last
location in the prefix is preserved while all keys below are removed
from the store. Any metadata extensions added to the group pointed to by
the prefix will be deleted as well - only a basic group-identifying
metadata file will remain.

#### Usage

    zarr_localstore$erase_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups or arrays to remove from the
  store, including in child groups.

#### Returns

`TRUE` if the operation proceeded, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `list_dir()`

Retrieve all keys and prefixes with a given prefix and which do not
contain the character "/" after the given prefix. In other words, this
retrieves all the nodes in the store below the node indicated by the
prefix.

#### Usage

    zarr_localstore$list_dir(prefix)

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

    zarr_localstore$list_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose nodes to list.

#### Returns

A character vector with all paths found in the store below the `prefix`
location, both for groups and arrays.

------------------------------------------------------------------------

### Method `set()`

Store a `(key, value)` pair. The key points to a specific file (shard or
chunk of an array) in a store, rather than a group or an array. The key
must be relative to the root of the store (so not start with a "/") and
may be composite. It must include the name of the file. An example would
be "group/subgroup/array/c0.0.0". The group hierarchy and the array must
have been created before. If the `value` exists, it will be overwritten.

#### Usage

    zarr_localstore$set(key, value)

#### Arguments

- `key`:

  The key whose value to set.

- `value`:

  The value to set, a complete chunk of data, a `raw` vector.

#### Returns

Self, invisibly, or an error.

------------------------------------------------------------------------

### Method `set_if_not_exists()`

Store a `(key, value)` pair. The key points to a specific file (shard or
chunk of an array) in a store, rather than a group or an array. The key
must be relative to the root of the store (so not start with a "/") and
may be composite. It must include the name of the file. An example would
be "group/subgroup/array/c0.0.0". The group hierarchy and the array must
have been created before. If the `key` exists, nothing will be written.

#### Usage

    zarr_localstore$set_if_not_exists(key, value)

#### Arguments

- `key`:

  The key whose value to set.

- `value`:

  The value to set, a complete chunk of data.

#### Returns

Self, invisibly, or an error.

------------------------------------------------------------------------

### Method [`get()`](https://rdrr.io/r/base/get.html)

Retrieve the value associated with a given key.

#### Usage

    zarr_localstore$get(key, prototype = NULL, byte_range = NULL)

#### Arguments

- `key`:

  Character string. The key for which to get data.

- `prototype`:

  Ignored. The only buffer type that is supported maps directly to an R
  raw vector.

- `byte_range`:

  If `NULL`, all data associated with the key is retrieved. If a single
  positive integer, all bytes starting from a given byte offset to the
  end of the object are returned. If a single negative integer, the
  final bytes are returned. If an integer vector of length 2, request a
  specific range of bytes where the end is exclusive. If the range ends
  after the end of the object, the entire remainder of the object will
  be returned. If the given range is zero-length or starts after the end
  of the object, an error will be returned.

#### Returns

An raw vector of data, or `NULL` if no data was found.

------------------------------------------------------------------------

### Method `get_metadata()`

Retrieve the metadata document of the node at the location indicated by
the `prefix` argument. The metadata will always be presented to the
caller in the Zarr v.3 format.

#### Usage

    zarr_localstore$get_metadata(prefix)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to retrieve.

#### Returns

A list with the metadata, or `NULL` if the prefix is not pointing to a
Zarr group or array.

------------------------------------------------------------------------

### Method `set_metadata()`

Set the metadata document of the node at the location indicated by the
`prefix` argument. The formatting of the metadata should always use the
Zarr v.3 format, it will be converted internally if the store is Zarr
v.2.

#### Usage

    zarr_localstore$set_metadata(prefix, metadata)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to set.

- `metadata`:

  The metadata to persist, either a `list` or an instance of
  [array_builder](https://r-cf.github.io/zarr/reference/array_builder.md).

#### Returns

Self, invisible

------------------------------------------------------------------------

### Method `is_group()`

Test if `path` is pointing to a Zarr group.

#### Usage

    zarr_localstore$is_group(path)

#### Arguments

- `path`:

  The path to test.

#### Returns

`TRUE` if the `path` points to a Zarr group, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `create_group()`

Create a new group in the store under the specified path.

#### Usage

    zarr_localstore$create_group(path, name)

#### Arguments

- `path`:

  The path to the parent group of the new group. Ignored when creating a
  root group.

- `name`:

  The name of the new group. This may be an empty string `""` to create
  a root group. It is an error to supply an empty string if a root group
  or array already exists.

#### Returns

A list with the metadata of the group, or an error if the group could
not be created.

------------------------------------------------------------------------

### Method `create_array()`

Create a new array in the store under the specified path to the `parent`
argument.

#### Usage

    zarr_localstore$create_array(parent, name, metadata)

#### Arguments

- `parent`:

  The path to the parent group of the new array. Ignored when creating a
  root array.

- `name`:

  The name of the new array. This may be an empty string `""` to create
  a root array. It is an error to supply an empty string if a root group
  or array already exists.

- `metadata`:

  A `list` with the metadata for the array. The list has to be valid for
  array construction. Use the
  [array_builder](https://r-cf.github.io/zarr/reference/array_builder.md)
  class to create and or test for validity. An element
  "chunk_key_encoding" will be added to the metadata if not already
  present or with a value other than a dot "." or a slash "/".

#### Returns

A list with the metadata of the array, or an error if the array could
not be created.
