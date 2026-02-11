# In-memory Zarr Store

This class implements a Zarr store in RAM memory. With this class Zarr
stores can be read and written to. Obviously, any data is not persisted
after the memory store is de-referenced and garbage-collected.

All data is stored in a list. The Zarr array itself has a list with the
metadata, its chunks have names like "c.0.0.0" and they have an R
array-like value.

This class performs no sanity checks on any of the arguments passed to
the methods, for performance reasons. Since this class should be
accessed through group and array objects, it is up to that code to
ensure that arguments are valid, in particular keys and prefixes.

## Super class

[`zarr::zarr_store`](https://r-cf.github.io/zarr/reference/zarr_store.md)
-\> `zarr_memorystore`

## Active bindings

- `friendlyClassName`:

  (read-only) Name of the class for printing.

- `separator`:

  (read-only) The separator of the memory store, always a dot '.'.

- `keys`:

  (read-only) The defined keys in the store.

## Methods

### Public methods

- [`zarr_memorystore$new()`](#method-zarr_memorystore-new)

- [`zarr_memorystore$exists()`](#method-zarr_memorystore-exists)

- [`zarr_memorystore$clear()`](#method-zarr_memorystore-clear)

- [`zarr_memorystore$erase()`](#method-zarr_memorystore-erase)

- [`zarr_memorystore$erase_prefix()`](#method-zarr_memorystore-erase_prefix)

- [`zarr_memorystore$list_dir()`](#method-zarr_memorystore-list_dir)

- [`zarr_memorystore$list_prefix()`](#method-zarr_memorystore-list_prefix)

- [`zarr_memorystore$set()`](#method-zarr_memorystore-set)

- [`zarr_memorystore$set_if_not_exists()`](#method-zarr_memorystore-set_if_not_exists)

- [`zarr_memorystore$get()`](#method-zarr_memorystore-get)

- [`zarr_memorystore$get_metadata()`](#method-zarr_memorystore-get_metadata)

- [`zarr_memorystore$create_group()`](#method-zarr_memorystore-create_group)

- [`zarr_memorystore$create_array()`](#method-zarr_memorystore-create_array)

Inherited methods

- [`zarr::zarr_store$getsize()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-getsize)
- [`zarr::zarr_store$getsize_prefix()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-getsize_prefix)
- [`zarr::zarr_store$is_empty()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-is_empty)
- [`zarr::zarr_store$list()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-list)
- [`zarr::zarr_store$set_metadata()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-set_metadata)

------------------------------------------------------------------------

### Method `new()`

Create an instance of this class.

#### Usage

    zarr_memorystore$new()

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method [`exists()`](https://rdrr.io/r/base/exists.html)

Check if a key exists in the store. The key can point to a group, an
array (having a metadata list as its value) or a chunk.

#### Usage

    zarr_memorystore$exists(key)

#### Arguments

- `key`:

  Character string. The key that the store will be searched for.

#### Returns

`TRUE` if argument `key` is found, `FALSE` otherwise.

------------------------------------------------------------------------

### Method `clear()`

Clear the store. Remove all keys and values from the store. Invoking
this method deletes all data and this action can not be undone.

#### Usage

    zarr_memorystore$clear()

#### Returns

`TRUE`. This operation always proceeds successfully once invoked.

------------------------------------------------------------------------

### Method `erase()`

Remove a key from the store. The key must point to an array or a chunk.
If the key points to an array, the key and all of subordinated keys are
removed.

#### Usage

    zarr_memorystore$erase(key)

#### Arguments

- `key`:

  Character string. The key to remove from the store.

#### Returns

`TRUE`. This operation always proceeds successfully once invoked, even
if argument `key` does not point to an existing key.

------------------------------------------------------------------------

### Method `erase_prefix()`

Remove all keys in the store that begin with a given prefix.

#### Usage

    zarr_memorystore$erase_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups or arrays to remove from the
  store, including in child groups.

#### Returns

`TRUE`. This operation always proceeds successfully once invoked, even
if argument `prefix` does not point to any existing keys.

------------------------------------------------------------------------

### Method `list_dir()`

Retrieve all keys with a given prefix and which do not contain the
character "/" after the given prefix. In other words, this retrieves all
the keys in the store below the key indicated by the prefix.

#### Usage

    zarr_memorystore$list_dir(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose nodes to list.

#### Returns

A character array with all keys found in the store immediately below the
`prefix`.

------------------------------------------------------------------------

### Method `list_prefix()`

Retrieve all keys and prefixes with a given prefix.

#### Usage

    zarr_memorystore$list_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to nodes to list.

#### Returns

A character vector with all paths found in the store below the `prefix`
location.

------------------------------------------------------------------------

### Method `set()`

Store a `(key, value)` pair. If the `value` exists, it will be
overwritten.

#### Usage

    zarr_memorystore$set(key, value)

#### Arguments

- `key`:

  The key whose value to set.

- `value`:

  The value to set, typically a complete chunk of data, a `raw` vector.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `set_if_not_exists()`

Store a `(key, value)` pair. If the `key` exists, nothing will be
written.

#### Usage

    zarr_memorystore$set_if_not_exists(key, value)

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

    zarr_memorystore$get(key, prototype = NULL, byte_range = NULL)

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

Retrieve the metadata document at the location indicated by the `prefix`
argument.

#### Usage

    zarr_memorystore$get_metadata(prefix)

#### Arguments

- `prefix`:

  The prefix whose metadata document to retrieve.

#### Returns

A list with the metadata, or `NULL` if the prefix is not pointing to a
Zarr array.

------------------------------------------------------------------------

### Method `create_group()`

Create a new group in the store under the specified path.

#### Usage

    zarr_memorystore$create_group(path, name)

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

Create a new array in the store under key constructed from the specified
path to the `parent` argument and the `name`. The key may not already
exist in the store.

#### Usage

    zarr_memorystore$create_array(parent, name, metadata)

#### Arguments

- `parent`:

  The path to the parent group of the new array. This is ignored if the
  `name` argument is the empty string.

- `name`:

  The name of the new array.

- `metadata`:

  A `list` with the metadata for the array. The list has to be valid for
  array construction. Use the
  [array_builder](https://r-cf.github.io/zarr/reference/array_builder.md)
  class to create and or test for validity. An element
  "chunk_key_encoding" will be added to the metadata if it not already
  there or contains an invalid separator.

#### Returns

A list with the metadata of the array, or an error if the array could
not be created.
