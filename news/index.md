# Changelog

## zarr (development version)

- `zarr_node::post_open()` method allows for processing that requires
  the Zarr hierarchy to be in place.
- Dynamically set a node in a Zarr hierarchy.
- Set metadata on a node in a memory store.
- Convention classes are now coded as attribute factories.
- Zarr package options can now be retrieved and modified with the
  [`zarr_options()`](https://r-cf.github.io/zarr/reference/zarr_options.md)
  function.
- Compute optimal chunking sizes from array shape when not set
  explicitly.
- In [`as_zarr()`](https://r-cf.github.io/zarr/reference/as_zarr.md),
  small arrays are not compressed. This is controlled by the
  `Zarr.options$min_compress` setting.
- Fix key listing in memory stores.

## zarr 0.4.1

CRAN release: 2026-06-14

- Hierarchy can now also be printed from any group. Zarr arrays from
  domain packages may use alternative glyphs.
- New `attribute()` method for `zarr_group` and `zarr_array` instances.
- Attributes can be nested by specifying a compound path when adding.
  JSON array attributes can be appended. JSON arrays can be deleted over
  compound paths, including JSON arrays.
- Attributes article updated.

## zarr 0.4.0

CRAN release: 2026-05-28

- Reading of sharded Zarr stores is now supported.
- The Zarr-registered “string” data type, an extension to the core
  specification, is now supported. This uses the “vlen-utf8” codec, also
  a registered extension to the core specification. For Zarr v.2 stores,
  this corresponds to the “\|O” data type; the “\<U\*” data type is also
  supported, using a mocked-up “ucs-4” codec (it is not a true codec or
  Zarr v.2 filter) to provide the mandatory “array -\> bytes” codec.
  This means that you can now read Zarr arrays that have character data.
  You can also create new Zarr arrays with character data.
- Nested attributes print better to the console.
- [`zarr_conventions()`](https://r-cf.github.io/zarr/reference/zarr_conventions.md)
  function returns `data.frame` of supported conventions.
- Ref convention code updated.
- Malformed “NaN”, “Infinity” and “-Infinity” in metadata solved.
- Better testing of fill values.
- Fixed deeply nested consolidated metadata.
- Fixed handling of scalar arrays.
- R dependency bumped to 4.2
- Using Rcpp for performance bottlenecks, using `future` for optional
  parallel processing of chunks and shards.

## zarr 0.3.0

CRAN release: 2026-04-18

- Extensible domain and convention mechanisms added, following
  [ZEP0004](https://zarr.dev/zeps/draft/ZEP0004.html). This enables
  developers to extend this Zarr implementation with domain-specific
  interfaces.
- Metadata is now writable as a complete object - expert use only.
- Fixed listing of keys in memory stores.
- Expanded documentation.

## zarr 0.2.0

CRAN release: 2026-02-11

- Zarr version 2 stores can be read. Data types supported are those also
  included in the v.3 core specification. The `compression` codec has to
  be one of those supported by the v.3 core specification or `zstd`.
  Filters are not yet supported.
- HTTP stores can be read but only for Zarr v.3 and v.2 single-array
  stores and Zarr v.2 stores with consolidated metadata present in the
  root group of the Zarr store.
- Chunk key encoding from v.2 and “default” and “v2” from v.3 supported.
- The `blosc` package is now imported as it is the default compression
  codec.
- `zstd` compression codec added.
- Fixed reading `integer64` data.

## zarr 0.1.1

CRAN release: 2025-12-06

- Initial code base. This release contains a fairly complete
  implementation of the Zarr core v.3 specification. As such, it will
  not be able to access Zarr v.2 stores.
- Support for adding and deleting attributes to groups and arrays.
