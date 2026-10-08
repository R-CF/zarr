# zarr (development version)

This is the prelude to the first stable release. This major release contains **API breaking changes**.

Code has been refactored to make it more agile and less error-prone. Two major changes have been implemented:

1. The `zarr_store` class is no longer used in the public-facing API. Most store-oriented tasks are now handled through the `zarr` class, including creating a new store.
2. Instantiating a `zarr_array` will create it in the store if it does not yet exist, and attach itself to its parent, usually a `zarr_group` but it could also be a `zarr` instance in the case of a single-array store.

These changes impact the signature of several methods:

- `zarr$new()` has several new arguments following the first `store` argument. All additional arguments are optional so existing code will remain functional. The `store` argument has additional functionality.
- `zarr_group$new()` and `zarr_array$new()` no longer have the `store` argument.
- Several other methods in these three classes have related signature changes, but these changes are not relevant for end users or application developers of this package.

Other features:

- New `zarr$save_to()` method can save a `zarr` object to a new store. This is handy to save a memory store to disk, to convert a v.2 store to a v.3 store, or to get a local copy of a remote store, among other uses. Parallel reads from HTTP and S3 stores speeds up the copying.
- New field `zarr` in class `zarr_node` to retrieve the `zarr` instance that manages the node.

Minor changes:

- The `array_builder` class has a field `data_type_from_storage.mode` that can make a Zarr data type from an R storage mode.
- `zarr.json` writes arrays for `shape` and `chunk_shape` for 1D axes.
- JSON writes use full numeric precision.
- `ref` convention uses released version v2.0.0.

# zarr 0.5.1

- Chunk management improved, size-limited cache with a LRU eviction scheme. The size of the cache (per array) can be controlled with the session option `chunk_cache_bytes`.
- New `zarr_array$raw_read` field can be set to control conversion of the Zarr array `fill_value` to R's `NA` upon reading (`FALSE`, default) or to skip the conversion (`TRUE`) for faster loading when data is known not to have fill values or when these are managed at the application level.
- Fix tests and example that use suggested package to run conditionally.

# zarr 0.5.0

- AWS S3 store access added for reading and, with appropriate authentication, writing. The function `s3_list_dir()` can be used to walk the directory listing of an S3 bucket to locate Zarr stores.
- New `zarr_array::resize()` method with which arrays can be resized, growing or shrinking across all dimensions simultaneously, including on the lower end of the dimensions. When changing the "low" side of the dimensions, which is always by full chunks, the indexing of all data changes to use the new origin.
- New `zarr_array::promote()` method which adds a dimension to the array.
- New `zarr_object` base class for name and attribute management.
- `dirty` field can be explicitly set on any node to force writing of the metadata to the store.
- `chunk_key_encoding` is automatically set in array metadata.
- New `optimal_chunking()` function to determine optimal chunking for an array, optionally applying different weights to dimensions or groups of dimensions.
- Better support for scalar arrays. Scalar arrays can now be constructed by the `array_builder` class and written to like regular arrays.
- Testing expanded.
- Documentation expanded and updated.

# zarr 0.4.2

- `zarr_node$post_open()` method allows for processing that requires the Zarr hierarchy to be in place.
- Dynamically set a node in a Zarr hierarchy.
- `zarr_node$relative_path()` method retrieves the relative path from the node to another node or a path string. `zarr_node$absolute_path()` turns a relative path starting from the current node into an absolute path. `walk_path()` traverses the Zarr hierarchy from the current node to a target node using relative node names, returning the requested node.
- Set metadata on a node in a memory store.
- Convention classes are now coded as attribute factories.
- Zarr package options can now be retrieved and modified with the `zarr_options()` function.
- Compute optimal chunking sizes from array shape when not set explicitly.
- In `as_zarr()`, small arrays are not compressed. This is controlled by the `Zarr.options$min_compress` setting.
- Fix key listing in memory stores.

# zarr 0.4.1

- Hierarchy can now also be printed from any group. Zarr arrays from domain packages may use alternative glyphs.
- New `attribute()` method for `zarr_group` and `zarr_array` instances.
- Attributes can be nested by specifying a compound path when adding. JSON array attributes can be appended. JSON arrays can be deleted over compound paths, including JSON arrays.
- Attributes article updated.

# zarr 0.4.0

- Reading of sharded Zarr stores is now supported.
- The Zarr-registered "string" data type, an extension to the core specification, is now supported. This uses the "vlen-utf8" codec, also a registered extension to the core specification. For Zarr v.2 stores, this corresponds to the "|O" data type; the "<U*" data type is also supported, using a mocked-up "ucs-4" codec (it is not a true codec or Zarr v.2 filter) to provide the mandatory "array -> bytes" codec. This means that you can now read Zarr arrays that have character data. You can also create new Zarr arrays with character data.
- Nested attributes print better to the console.
- `zarr_conventions()` function returns `data.frame` of supported conventions.
- Ref convention code updated.
- Malformed "NaN", "Infinity" and "-Infinity" in metadata solved.
- Better testing of fill values.
- Fixed deeply nested consolidated metadata.
- Fixed handling of scalar arrays.
- R dependency bumped to 4.2
- Using Rcpp for performance bottlenecks, using `future` for optional parallel processing of chunks and shards.

# zarr 0.3.0

- Extensible domain and convention mechanisms added, following [ZEP0004](https://zarr.dev/zeps/draft/ZEP0004.html). This enables developers to extend this Zarr implementation with domain-specific interfaces.
- Metadata is now writable as a complete object - expert use only.
- Fixed listing of keys in memory stores.
- Expanded documentation.

# zarr 0.2.0

- Zarr version 2 stores can be read. Data types supported are those also included in the v.3 core specification. The `compression` codec has to be one of those supported by the v.3 core specification or `zstd`. Filters are not yet supported.
- HTTP stores can be read but only for Zarr v.3 and v.2 single-array stores and Zarr v.2 stores with consolidated metadata present in the root group of the Zarr store.
- Chunk key encoding from v.2 and "default" and "v2" from v.3 supported.
- The `blosc` package is now imported as it is the default compression codec.
- `zstd` compression codec added.
- Fixed reading `integer64` data.

# zarr 0.1.1

- Initial code base. This release contains a fairly complete implementation of the Zarr core v.3 specification. As such, it will not be able to access Zarr v.2 stores.
- Support for adding and deleting attributes to groups and arrays.
