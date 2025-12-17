# zarr (development version)

- Zarr version 2 stores can be read. Data types supported are those also included in the v.3 core specification. The `compression` codec has to be one of those supported by the v.3 core specification or `zstd`. Filters are not yet supported.
- The `blosc` package is now imported as it is the default compression codec.
- `zstd` compression codec added.

# zarr 0.1.1

- Initial code base. This release contains a fairly complete implementation of the Zarr core v.3 specification. As such, it will not be able to access Zarr v.2 stores.
- Support for adding and deleting attributes to groups and arrays.
