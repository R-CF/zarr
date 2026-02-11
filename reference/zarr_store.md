# Zarr Abstract Store

This class implements a Zarr abstract store. It provides the basic
plumbing for specific implementations of a Zarr store. It implements the
Zarr abstract store interface, with some extensions from the Python
`zarr.abc.store.Store` abstract class. Functions `set_partial_values()`
and `get_partial_values()` are not implemented.

## References

https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html#abstract-store-interface

## Active bindings

- `friendlyClassName`:

  (read-only) Name of the class for printing.

- `read_only`:

  (read-only) Flag to indicate if the store is read-only.

- `supports_consolidated_metadata`:

  Flag to indicate if the store can consolidate metadata.

- `supports_deletes`:

  Flag to indicate if keys and arrays can be deleted.

- `supports_listing`:

  Flag to indicate if the store can list its keys.

- `supports_partial_writes`:

  Deprecated, always `FALSE`.

- `supports_writes`:

  Flag to indicate if the store can write data.

- `version`:

  (read-only) The Zarr version of the store.

- `separator`:

  (read-only) The default separator between elements of chunks of arrays
  in the store. Every store typically has a default which is used when
  creating arrays. The actual chunk separator being used is determined
  by looking at the "chunk_key_encoding" attribute of each array.

## Methods

### Public methods

- [`zarr_store$new()`](#method-zarr_store-new)

- [`zarr_store$clear()`](#method-zarr_store-clear)

- [`zarr_store$erase()`](#method-zarr_store-erase)

- [`zarr_store$erase_prefix()`](#method-zarr_store-erase_prefix)

- [`zarr_store$exists()`](#method-zarr_store-exists)

- [`zarr_store$get()`](#method-zarr_store-get)

- [`zarr_store$getsize()`](#method-zarr_store-getsize)

- [`zarr_store$getsize_prefix()`](#method-zarr_store-getsize_prefix)

- [`zarr_store$is_empty()`](#method-zarr_store-is_empty)

- [`zarr_store$list()`](#method-zarr_store-list)

- [`zarr_store$list_dir()`](#method-zarr_store-list_dir)

- [`zarr_store$list_prefix()`](#method-zarr_store-list_prefix)

- [`zarr_store$set()`](#method-zarr_store-set)

- [`zarr_store$set_if_not_exists()`](#method-zarr_store-set_if_not_exists)

- [`zarr_store$get_metadata()`](#method-zarr_store-get_metadata)

- [`zarr_store$set_metadata()`](#method-zarr_store-set_metadata)

- [`zarr_store$create_group()`](#method-zarr_store-create_group)

- [`zarr_store$create_array()`](#method-zarr_store-create_array)

------------------------------------------------------------------------

### Method `new()`

Create an instance of this class. Since this class is "abstract", it
should not be instantiated directly - it is intended to be called by
descendant classes, exclusively.

#### Usage

    zarr_store$new(read_only = FALSE, version = 3L)

#### Arguments

- `read_only`:

  Flag to indicate if the store is read-only. Default `FALSE`.

- `version`:

  The version of the Zarr store. By default this is 3.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `clear()`

Clear the store. Remove all keys and values from the store.

#### Usage

    zarr_store$clear()

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `erase()`

Remove a key from the store. This method is part of the abstract store
interface in ZEP0001.

#### Usage

    zarr_store$erase(key)

#### Arguments

- `key`:

  Character string. The key to remove from the store.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `erase_prefix()`

Remove all keys and prefixes in the store that begin with a given
prefix. This method is part of the abstract store interface in ZEP0001.

#### Usage

    zarr_store$erase_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups or arrays to remove from the
  store, including in child groups.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method [`exists()`](https://rdrr.io/r/base/exists.html)

Check if a key exists in the store.

#### Usage

    zarr_store$exists(key)

#### Arguments

- `key`:

  Character string. The key that the store will be searched for.

#### Returns

`TRUE` if argument `key` is found, `FALSE` otherwise.

------------------------------------------------------------------------

### Method [`get()`](https://rdrr.io/r/base/get.html)

Retrieve the value associated with a given key. This method is part of
the abstract store interface in ZEP0001.

#### Usage

    zarr_store$get(key, prototype, byte_range)

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

### Method `getsize()`

Return the size, in bytes, of a value in a Store.

#### Usage

    zarr_store$getsize(key)

#### Arguments

- `key`:

  Character string. The key whose length will be returned.

#### Returns

The size, in bytes, of the object.

------------------------------------------------------------------------

### Method `getsize_prefix()`

Return the size, in bytes, of all objects found under the group
indicated by the prefix.

#### Usage

    zarr_store$getsize_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups to scan.

#### Returns

The size, in bytes, of all the objects under a group, as a single
integer value.

------------------------------------------------------------------------

### Method `is_empty()`

Is the group empty?

#### Usage

    zarr_store$is_empty(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to the group to scan.

#### Returns

`TRUE` is the group indicated by argument `prefix` has no sub-groups or
arrays, `FALSE` otherwise.

------------------------------------------------------------------------

### Method [`list()`](https://rdrr.io/r/base/list.html)

Retrieve all keys in the store. This method is part of the abstract
store interface in ZEP0001.

#### Usage

    zarr_store$list()

#### Returns

A character vector with all keys found in the store, both for groups and
arrays.

------------------------------------------------------------------------

### Method `list_dir()`

Retrieve all keys and prefixes with a given prefix and which do not
contain the character "/" after the given prefix. This method is part of
the abstract store interface in ZEP0001.

#### Usage

    zarr_store$list_dir(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups to list.

#### Returns

A list with all keys found in the store immediately below the `prefix`,
both for groups and arrays.

------------------------------------------------------------------------

### Method `list_prefix()`

Retrieve all keys and prefixes with a given prefix. This method is part
of the abstract store interface in ZEP0001.

#### Usage

    zarr_store$list_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups to list.

#### Returns

A character vector with all fully-qualified keys found in the store,
both for groups and arrays.

------------------------------------------------------------------------

### Method `set()`

Store a (key, value) pair.

#### Usage

    zarr_store$set(key, value)

#### Arguments

- `key`:

  The key whose value to set.

- `value`:

  The value to set, typically a chunk of data.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `set_if_not_exists()`

Store a key to argument `value` if the key is not already present. This
method is part of the abstract store interface in ZEP0001.

#### Usage

    zarr_store$set_if_not_exists(key, value)

#### Arguments

- `key`:

  The key whose value to set.

- `value`:

  The value to set, typically an R array.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### Method `get_metadata()`

Retrieve the metadata document of the node at the location indicated by
the `prefix` argument.

#### Usage

    zarr_store$get_metadata(prefix)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to retrieve.

------------------------------------------------------------------------

### Method `set_metadata()`

Set the metadata document of the node at the location indicated by the
`prefix` argument. This is a no-op for stores that have no writing
capability. Other stores must override this method.

#### Usage

    zarr_store$set_metadata(prefix, metadata)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to set.

- `metadata`:

  The metadata to persist, either a `list` or an instance of
  [array_builder](https://r-cf.github.io/zarr/reference/array_builder.md).

#### Returns

Self, invisible.

------------------------------------------------------------------------

### Method `create_group()`

Create a new group in the store under the specified path to the `parent`
argument. The `parent` path must point to a Zarr group.

#### Usage

    zarr_store$create_group(parent, name)

#### Arguments

- `parent`:

  The path to the parent group of the new group.

- `name`:

  The name of the new group.

#### Returns

A list with the metadata of the group, or an error if the group could
not be created.

------------------------------------------------------------------------

### Method `create_array()`

Create a new array in the store under the specified path to the `parent`
argument. The `parent` path must point to a Zarr group.

#### Usage

    zarr_store$create_array(parent, name)

#### Arguments

- `parent`:

  The path to the parent group of the new array.

- `name`:

  The name of the new array.

#### Returns

A list with the metadata of the array, or an error if the array could
not be created.
