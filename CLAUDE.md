# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```r
# Install dependencies
devtools::install_deps()

# Load package for interactive development
devtools::load_all()

# Run all tests
devtools::test()

# Run a single test file
testthat::test_file("tests/testthat/test-zarr.R")

# Run specific test by name pattern
devtools::test(filter = "Basic functionality")

# Rebuild documentation
devtools::document()

# Full R CMD check
devtools::check()
```

## Architecture

This is a native R implementation of the [Zarr v3 specification](https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html), using R6 classes throughout. The class hierarchy maps directly to Zarr concepts:

```
zarr_extension          # base for all named extension points
  zarr_codec            # array→array or bytes→bytes transformations
    zarr_codec_transpose, zarr_codec_bytes, zarr_codec_vlenutf8,
    zarr_codec_ucs4, zarr_codec_blosc, zarr_codec_zstd,
    zarr_codec_gzip, zarr_codec_crc32c
  chunk_grid_regular    # manages chunk I/O for one array
  zarr_data_type        # maps Zarr types to R storage modes

zarr_store              # abstract key-value store interface
  zarr_memorystore      # in-memory (list-backed)
  zarr_localstore       # local filesystem
  zarr_httpstore        # HTTP (read-only)

zarr_node               # base for hierarchy nodes
  zarr_group            # container node
  zarr_array            # leaf node with data

zarr                    # top-level object; owns store + root node

zarr_domain             # base for application-domain plugins
zarr_convention         # base for attribute-level convention plugins
array_builder           # mutable builder for array metadata documents
```

**Data flow for reading a chunk:**
`zarr_array$read()` → `chunk_grid_regular$read()` → `zarr_store$get()` → codec chain applied in reverse order (bytes-codecs first, then array-codecs) → R array returned to caller.

**Data flow for writing a chunk:**
`zarr_array$write()` → `chunk_grid_regular$write()` → codec chain applied in forward order → `zarr_store$set()`.

**Codec pipeline:** Codecs are stored in `array_builder` as a named list and must form a valid chain: the first codec's `from` must be `"array"`, the last codec's `to` must be `"bytes"`, and adjacent codecs must agree on the intermediate type. `array_builder$add_codec()` enforces this at construction time.

**Zarr v2 compatibility:** `zarr_store` has a private `metadata_v2_to_v3()` method that converts v2 metadata on the fly. Stores detect the version from `zarr.json` vs `.zarray`/`.zgroup` keys. Internally everything is represented as v3.

**Ordering:** R uses column-major (Fortran) order; Zarr canonical is row-major (C order). By default `array_builder` inserts a `transpose` codec so data is stored in native R order without permutation. Setting `array_builder$portable <- TRUE` removes the transpose codec, causing data to be permuted on write/read for cross-language compatibility.

**Extension points:** New stores inherit `zarr_store`; new codecs inherit `zarr_codec`; new domains inherit `zarr_domain` and must be registered via `zarr_register_domain()`; new conventions inherit `zarr_convention`.

**Global state:**
- `Zarr.domains` — environment of registered domain objects.
- `Zarr.options` — environment with `chunk_length` (default 100L) and `eps` (float comparison tolerance).

## Key implementation details

- All paths in the public API are `/`-prefixed (e.g. `"/my_array"`); internal store keys are prefix strings without a leading slash (e.g. `"my_array/zarr.json"`).
- Zarr indexing is 0-based in the spec and in stored chunk keys; all R-facing APIs are 1-based.
- `chunk_grid_regular` caches `chunk_grid_regular_IO` instances per chunk in a `.chunk_map` environment to avoid repeated allocation.
- The `%||%` null-coalescing operator and `.size_string()`, `.protocol()`, `.buildNode()` helpers live in `R/utils.R`.
- Optional codecs (`zstd`, `gzip`, `crc32c`) require `qs2`, `zlib`, and `digest` respectively; these are in `Suggests`, not `Imports`, so they are checked with `requireNamespace()` at runtime.
