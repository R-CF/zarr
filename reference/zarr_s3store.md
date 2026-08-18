# Zarr Store for AWS S3 (and S3-compatible) access

This class implements a Zarr S3 store, read/write capable for
authenticated users. It uses the `paws.storage` package for all S3
operations, including credential resolution, so this class never handles
secret keys directly unless the caller explicitly passes them through.

Like
[zarr_httpstore](https://r-cf.github.io/zarr/reference/zarr_httpstore.md),
this class will look for consolidated metadata (`.zmetadata`) or a
`zarr.json` / `.zarray` / `.zgroup` document at the configured prefix to
identify the store version and root node. Unlike the HTTP store, this
class does not *need* consolidated metadata to enumerate nodes: S3's
`ListObjectsV2` API is used directly for `list_dir()` and
`list_prefix()`, so the store reflects the live state of the bucket.

Credentials are resolved by `paws.storage` using its standard provider
chain (environment variables, shared credentials file / profile, IAM
role or instance/task metadata, SSO). Pass `profile` to select a named
profile, or explicit `access_key`/`secret_key`/`session_token` for
credentials threaded through from elsewhere. If none of those are given,
the store defaults to anonymous (unsigned) requests, since
`paws.storage` does not fall back to anonymous access on its own and the
common case for a freshly-opened store is a public bucket; pass
`anonymous = FALSE` explicitly to force normal credential resolution
with none of the above supplied (e.g. to pick up IAM role / instance
metadata credentials with no explicit profile or key).

NOTE: this class performs no sanity checks on any of the arguments
passed to the methods, for performance reasons, consistent with
[zarr_httpstore](https://r-cf.github.io/zarr/reference/zarr_httpstore.md).
It should be accessed through group and array objects.

## Super class

[`zarr_store`](https://r-cf.github.io/zarr/reference/zarr_store.md) -\>
`zarr_s3store`

## Active bindings

- `friendlyClassName`:

  (read-only) Name of the class for printing.

- `root`:

  (read-only) The bucket and prefix of the store, as `s3://`.

- `uri`:

  (read-only) The URI of the store location, identical to `root`.

- `separator`:

  (read-only) The default chunk separator of the store, usually a slash
  '/'.

## Methods

### Public methods

- [`zarr_s3store$new()`](#method-zarr_s3store-initialize)

- [`zarr_s3store$exists()`](#method-zarr_s3store-exists)

- [`zarr_s3store$clear()`](#method-zarr_s3store-clear)

- [`zarr_s3store$erase()`](#method-zarr_s3store-erase)

- [`zarr_s3store$erase_prefix()`](#method-zarr_s3store-erase_prefix)

- [`zarr_s3store$list_dir()`](#method-zarr_s3store-list_dir)

- [`zarr_s3store$list_prefix()`](#method-zarr_s3store-list_prefix)

- [`zarr_s3store$list()`](#method-zarr_s3store-list)

- [`zarr_s3store$list_chunks()`](#method-zarr_s3store-list_chunks)

- [`zarr_s3store$rename()`](#method-zarr_s3store-rename)

- [`zarr_s3store$getsize()`](#method-zarr_s3store-getsize)

- [`zarr_s3store$getsize_prefix()`](#method-zarr_s3store-getsize_prefix)

- [`zarr_s3store$is_empty()`](#method-zarr_s3store-is_empty)

- [`zarr_s3store$set()`](#method-zarr_s3store-set)

- [`zarr_s3store$set_if_not_exists()`](#method-zarr_s3store-set_if_not_exists)

- [`zarr_s3store$get()`](#method-zarr_s3store-get)

- [`zarr_s3store$get_metadata()`](#method-zarr_s3store-get_metadata)

- [`zarr_s3store$set_metadata()`](#method-zarr_s3store-set_metadata)

- [`zarr_s3store$is_group()`](#method-zarr_s3store-is_group)

- [`zarr_s3store$create_group()`](#method-zarr_s3store-create_group)

- [`zarr_s3store$create_array()`](#method-zarr_s3store-create_array)

Inherited methods

- [`zarr_store$rename_prefix()`](https://r-cf.github.io/zarr/reference/zarr_store.html#method-rename_prefix)

------------------------------------------------------------------------

### `zarr_s3store$new()`

Create an instance of this class.

#### Usage

    zarr_s3store$new(
      bucket,
      prefix = "",
      region = NULL,
      profile = NULL,
      access_key = NULL,
      secret_key = NULL,
      session_token = NULL,
      endpoint = NULL,
      path_style = NULL,
      anonymous = NULL,
      read_only = FALSE
    )

#### Arguments

- `bucket`:

  Character string. The S3 bucket name.

- `prefix`:

  Character string. The key prefix within the bucket that acts as the
  root of this store (e.g. `"datasets/mycube/"`). Use `""` for the
  bucket root. A trailing `/` is added if missing and the prefix is
  non-empty.

- `region`:

  Character string, AWS region, e.g. `"eu-west-1"`. If `NULL`, resolved
  by `paws.storage` from the environment/config.

- `profile`:

  Character string, a named profile from the shared AWS credentials
  file. Ignored if `access_key` is supplied.

- `access_key, secret_key, session_token`:

  Optional explicit credentials, for cases where they must be threaded
  through from elsewhere rather than resolved by `paws.storage` itself.
  Prefer `profile` or the default provider chain over these.

- `endpoint`:

  Character string. Optional custom endpoint URL, for S3-compatible
  backends (MinIO, Ceph RGW, EMBASSY Cloud, etc.) rather than AWS S3.

- `path_style`:

  Logical. Force path-style addressing (`endpoint/bucket/key`) instead
  of virtual-hosted-style (`bucket.endpoint/key`). Non-AWS S3-compatible
  backends generally only support path-style, so this defaults to `TRUE`
  whenever `endpoint` is supplied, and `FALSE` (AWS default) otherwise.
  Set explicitly to override.

- `anonymous`:

  Logical. If `TRUE`, make unsigned requests, for public buckets. If
  `FALSE`, use `paws.storage`'s normal credential resolution (explicit
  `profile`/`access_key`, then its default provider chain). If left
  `NULL` (the default), this is decided automatically: `TRUE` when
  neither `profile` nor `access_key` was given, `FALSE` otherwise.
  `paws.storage` does not fall back to unsigned requests on its own — a
  call against a public bucket with no credentials configured fails
  outright rather than trying anonymously, which is what this default is
  for.

- `read_only`:

  Logical. If `TRUE`, disable all write methods (`set()`, `erase()`,
  etc. become no-ops), regardless of the permissions of the underlying
  credentials. Default `FALSE`.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### `zarr_s3store$exists()`

Check if a key exists in the store.

#### Usage

    zarr_s3store$exists(key)

#### Arguments

- `key`:

  Character string. The key that the store will be searched for.

#### Returns

`TRUE` if argument `key` is found, `FALSE` otherwise.

------------------------------------------------------------------------

### `zarr_s3store$clear()`

Remove all objects below this store's prefix. No-op if the store was
opened with `read_only = TRUE`.

#### Usage

    zarr_s3store$clear()

#### Returns

`TRUE` on success, `FALSE` otherwise.

------------------------------------------------------------------------

### `zarr_s3store$erase()`

Remove a single key from the store. No-op if the store was opened with
`read_only = TRUE`.

#### Usage

    zarr_s3store$erase(key)

#### Arguments

- `key`:

  Character string. The key to remove.

#### Returns

`TRUE` on success, `FALSE` otherwise.

------------------------------------------------------------------------

### `zarr_s3store$erase_prefix()`

Remove all keys below a prefix. Batches deletes in groups of up to 1000,
the S3 `DeleteObjects` limit. No-op if the store was opened with
`read_only = TRUE`.

#### Usage

    zarr_s3store$erase_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose keys to remove.

#### Returns

`TRUE` on success, `FALSE` otherwise.

------------------------------------------------------------------------

### `zarr_s3store$list_dir()`

Retrieve the immediate child nodes below a prefix (single path component
only), using S3's native `Delimiter` support.

#### Usage

    zarr_s3store$list_dir(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose nodes to list.

#### Returns

A character vector of node names immediately below `prefix`.

------------------------------------------------------------------------

### `zarr_s3store$list_prefix()`

Retrieve all keys below a prefix (recursive).

#### Usage

    zarr_s3store$list_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix whose nodes to list.

#### Returns

A character vector with all paths found below `prefix`, prefixed with
`/` for consistency with
[zarr_httpstore](https://r-cf.github.io/zarr/reference/zarr_httpstore.md).

------------------------------------------------------------------------

### `zarr_s3store$list()`

Retrieve all keys in the store.

#### Usage

    zarr_s3store$list()

#### Returns

A character vector with all keys found in the store.

------------------------------------------------------------------------

### `zarr_s3store$list_chunks()`

Retrieve all chunk (and shard) keys stored for the array at the given
prefix. Used internally to support resizing and promoting arrays.

#### Usage

    zarr_s3store$list_chunks(prefix)

#### Arguments

- `prefix`:

  The prefix of the array whose chunk keys to retrieve.

#### Returns

A character vector of full store keys for chunk/shard files, excluding
the array's own metadata document.

------------------------------------------------------------------------

### `zarr_s3store$rename()`

Rename a key in the store, moving its value without necessarily reading
or re-encoding it. Used internally to support resizing and promoting
arrays. The default implementation is a plain copy, for stores without a
cheaper native operation.

#### Usage

    zarr_s3store$rename(old_key, new_key)

#### Arguments

- `old_key, new_key`:

  Character strings, the source and destination keys. `old_key` must
  exist; `new_key` is overwritten if it exists.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_s3store$getsize()`

Return the size, in bytes, of a value in the store, via a `HeadObject`
request (S3-native, no need to download the object).

#### Usage

    zarr_s3store$getsize(key)

#### Arguments

- `key`:

  Character string. The key whose length will be returned.

#### Returns

The size, in bytes, of the object.

------------------------------------------------------------------------

### `zarr_s3store$getsize_prefix()`

Return the total size, in bytes, of all objects found under the group
indicated by `prefix`, summed from a single (paginated) `ListObjectsV2`
scan rather than per-key `HeadObject` calls.

#### Usage

    zarr_s3store$getsize_prefix(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to groups to scan.

#### Returns

The total size, in bytes, as a single numeric value.

------------------------------------------------------------------------

### `zarr_s3store$is_empty()`

Is the group empty? Uses a single `MaxKeys = 1` `ListObjectsV2` request
rather than a full listing.

#### Usage

    zarr_s3store$is_empty(prefix)

#### Arguments

- `prefix`:

  Character string. The prefix to the group to scan.

#### Returns

`TRUE` if the group indicated by argument `prefix` has no sub-groups or
arrays, `FALSE` otherwise.

------------------------------------------------------------------------

### `zarr_s3store$set()`

Store a `(key, value)` pair. No-op if the store was opened with
`read_only = TRUE`.

Single-request upload only (S3's ~5 GB `PutObject` limit); this is not
expected to matter for typical Zarr chunk sizes. If you start writing
very large chunks (or use very large shards), this needs a
multipart-upload path instead — not implemented here.

#### Usage

    zarr_s3store$set(key, value)

#### Arguments

- `key`:

  Character string. The key to write to.

- `value`:

  Raw vector. The data to store.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_s3store$set_if_not_exists()`

Store a `(key, value)` pair only if the key does not already exist.
No-op if the store was opened with `read_only = TRUE`.

Uses a conditional `PutObject` with `IfNoneMatch = "*"` for atomic
create-if-absent semantics — no separate existence check, no race
window. This is an AWS S3 feature added in August 2024; it requires a
`paws.storage` version whose S3 client exposes `IfNoneMatch` on
`put_object()`, and a backend that honors it. Most S3-compatible
services (older MinIO releases, some others) reject or ignore the header
— if you're targeting one of those, this will need a fallback to a
check-then-put instead, which reintroduces the race.

#### Usage

    zarr_s3store$set_if_not_exists(key, value)

#### Arguments

- `key`:

  Character string. The key to write to.

- `value`:

  Raw vector. The data to store.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_s3store$get()`

Retrieve the value associated with a given key.

#### Usage

    zarr_s3store$get(key, prototype = NULL, byte_range = NULL)

#### Arguments

- `key`:

  Character string. The key for which to get data.

- `prototype`:

  Ignored. The only buffer type that is supported maps directly to an R
  raw vector.

- `byte_range`:

  As in
  [zarr_httpstore](https://r-cf.github.io/zarr/reference/zarr_httpstore.md):
  `NULL` for the whole object, a single positive integer for an
  open-ended range from that offset, a single negative integer for the
  final N bytes, or a length-2 vector `c(start, end)` with an exclusive
  end.

#### Returns

A raw vector with the data pointed at by the key, or `NULL` if the key
does not exist.

------------------------------------------------------------------------

### `zarr_s3store$get_metadata()`

Retrieve the metadata document of the node at `prefix`, always presented
in Zarr v.3 format.

#### Usage

    zarr_s3store$get_metadata(prefix)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to retrieve.

#### Returns

A list with the metadata, or `NULL` if the prefix does not point to a
Zarr group or array.

------------------------------------------------------------------------

### `zarr_s3store$set_metadata()`

Write the metadata document for the node at `prefix`. No-op if the store
was opened with `read_only = TRUE`.

#### Usage

    zarr_s3store$set_metadata(prefix, metadata)

#### Arguments

- `prefix`:

  The prefix of the node whose metadata document to write.

- `metadata`:

  A list with the Zarr v.3-format metadata to write.

#### Returns

Self, invisibly.

------------------------------------------------------------------------

### `zarr_s3store$is_group()`

Test if `path` is pointing to a Zarr group.

#### Usage

    zarr_s3store$is_group(path)

#### Arguments

- `path`:

  The path to test.

#### Returns

`TRUE` if the `path` points to a Zarr group, `FALSE` otherwise.

------------------------------------------------------------------------

### `zarr_s3store$create_group()`

Create a new group in the store under `parent`. Errors if the store was
opened with `read_only = TRUE`.

#### Usage

    zarr_s3store$create_group(parent, name)

#### Arguments

- `parent`:

  Character string. Path of the parent node.

- `name`:

  Character string. Name of the new group.

#### Returns

A list with the metadata of the newly-created group.

------------------------------------------------------------------------

### `zarr_s3store$create_array()`

Create a new array in the store under `parent`. As with
[zarr_httpstore](https://r-cf.github.io/zarr/reference/zarr_httpstore.md),
the abstract interface's `create_array(parent, name)` is extended here
with an explicit `metadata` argument, since array metadata (shape,
dtype, chunking, codecs) cannot be inferred and must be supplied by the
caller. Errors if the store was opened with `read_only = TRUE`.

#### Usage

    zarr_s3store$create_array(parent, name, metadata)

#### Arguments

- `parent`:

  Character string. Path of the parent node.

- `name`:

  Character string. Name of the new array.

- `metadata`:

  A list with the Zarr v.3-format array metadata.

#### Returns

A list with the metadata of the newly-created array, as written.
