# Changelog

## zarr (development version)

## zarr 0.2.0

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
