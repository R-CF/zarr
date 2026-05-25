# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Commands

``` r

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

## Developer preferences

Patrick values clean abstraction and inheritance hierarchies. When
suggesting code: - Prefer R6 inheritance over copy-pasting fields and
methods across classes - Identify opportunities to push shared logic
into base classes - Avoid duplicating validation or initialisation code
that a `super$initialize()` call already handles - Keep classes focused:
one class, one responsibility

## Architecture

This is a native R implementation of the [Zarr v3
specification](https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html),
using R6 classes throughout. The class hierarchy maps directly to Zarr
concepts:

    zarr_extension          # base for all named extension points
      zarr_codec            # array→array or bytes→bytes transformations
        zarr_codec_transpose, zarr_codec_bytes, zarr_codec_vlenutf8,
        zarr_codec_blosc, zarr_codec_zstd, zarr_codec_gzip, zarr_codec_crc32c,
        zarr_codec_ucs4,    # not a real codec, included to support the <U* data type
        zarr_codec_sharding # display-only placeholder; real logic in chunk_grid_sharded
      chunking              # base class for all chunk grid management
        chunk_grid_regular  # regular chunking: manages chunk I/O for one array
        chunk_grid_sharded  # sharded chunking: manages shard I/O for one array (read-only)
      zarr_data_type        # maps Zarr types to R storage modes

    zarr_store              # abstract key-value store interface
      zarr_memorystore      # in-memory (list-backed)
      zarr_localstore       # local filesystem (supports byte-range reads)
      zarr_httpstore        # HTTP (read-only, supports byte-range reads via Range header)

    zarr_node               # base for hierarchy nodes
      zarr_group            # container node
      zarr_array            # leaf node with data

    zarr                    # top-level object; owns store + root node

    zarr_domain             # base for application-domain plugins
    zarr_convention         # base for attribute-level convention plugins
    array_builder           # mutable builder for array metadata documents

**Internal chunk/shard I/O classes** (not exported):

    chunk_grid_regular_IO   # read/write buffer for a single regular chunk
    chunk_grid_sharded_IO   # read buffer for a single shard file

**Data flow for reading a regular chunk:** `zarr_array$read()` →
`chunk_grid_regular$read()` → `zarr_store$get()` → codec chain applied
in reverse order (bytes-codecs first, then array-codecs) → R array
returned to caller.

**Data flow for reading a sharded array:** `zarr_array$read()` →
`chunk_grid_sharded$read()` → for each touched shard:
`chunk_grid_sharded_IO$read()` → `load_index()` (byte-range read of
shard index) → for each touched inner chunk: `load_inner()` (byte-range
read + inner codec pipeline) → assembled R array returned to caller.

**Data flow for writing a regular chunk:** `zarr_array$write()` →
`chunk_grid_regular$write()` → codec chain applied in forward order →
`zarr_store$set()`.

Writing sharded arrays is not implemented (read-only). If a user
requests write support, open an issue.

**Sharding implementation notes:** - Sharding is treated as a chunking
topology, not a codec, despite being specified as a codec in Zarr v3.
`chunk_grid_sharded` parallels `chunk_grid_regular` and is transparent
to `zarr_array`. - `zarr_codec_sharding` exists only as a display
placeholder in the codec list (for
[`print()`](https://rdrr.io/r/base/print.html) output). It does not
participate in encode/decode. Metadata serialisation for sharded arrays
goes through `chunk_grid_sharded$metadata_fragment()`. - The shard index
is stored as a `[2 x n_inner]` `integer64` matrix (offset, length per
inner chunk). Sentinel value `0xFFFFFFFFFFFFFFFF` (-1L in integer64)
marks absent inner chunks. - Index byte order is little-endian; parsed
via `readBin(..., what='double', size=8, endian='little')` followed by
`class(buf) <- 'integer64'` for bitwise reinterpretation. - `bit64` is
required for sharded arrays; checked at runtime via
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html). - CRC32c
checksums on the index are verified via
`digest::digest(..., algo='crc32c', raw=TRUE)` with
[`rev()`](https://rdrr.io/r/base/rev.html) to correct for endianness. -
Inner chunk C-order linearisation uses strides:
`c(rev(cumprod(rev(inner_grid)))[-1L], 1L)`.

**Codec pipeline:** Codecs are stored in `array_builder` as a named list
and must form a valid chain: the first codec’s `from` must be `"array"`,
the last codec’s `to` must be `"bytes"`, and adjacent codecs must agree
on the intermediate type. `array_builder$add_codec()` enforces this at
construction time. For sharded arrays, the outer codec list contains
only `zarr_codec_sharding`; the inner and index codec pipelines are
instantiated via `.build_codec_pipeline()` and stored in
`chunk_grid_sharded`.

**Zarr v2 compatibility:** `zarr_store` has a private
`metadata_v2_to_v3()` method that converts v2 metadata on the fly.
Stores detect the version from `zarr.json` vs `.zarray`/`.zgroup` keys.
Internally everything is represented as v3.

**Ordering:** R uses column-major (Fortran) order; Zarr canonical is
row-major (C order). By default `array_builder` inserts a `transpose`
codec so data is stored in native R order without permutation. Setting
`array_builder$portable <- TRUE` removes the transpose codec, causing
data to be permuted on write/read for cross-language compatibility.
Sharded arrays produced by other tools (Python/zarr-python) are always
in C order; `chunk_grid_sharded_IO$load_inner()` handles the permutation
via [`aperm()`](https://rdrr.io/r/base/aperm.html) when no transpose
codec is present.

**HTTP byte-range reads:** `zarr_httpstore$get()` supports the same
`byte_range` interface as `zarr_localstore$get()`: `NULL` (whole
object), single negative integer (suffix range), single positive integer
(offset to end), or length-2 vector `c(start, end)` with exclusive end.
Implemented via curl `Range` header; servers must support HTTP range
requests (206 Partial Content). This is a hard requirement for sharded
HTTP stores.

**Extension points:** New stores inherit `zarr_store`; new codecs
inherit `zarr_codec`; new domains inherit `zarr_domain` and must be
registered via
[`zarr_register_domain()`](https://r-cf.github.io/zarr/reference/zarr_register_domain.md);
new conventions inherit `zarr_convention`; new chunking schemes inherit
`chunking`.

**Global state:** - `Zarr.domains` — environment of registered domain
objects. - `Zarr.options` — environment with `chunk_length` (default
100L) and `eps` (float comparison tolerance).

## Key implementation details

- All paths in the public API are `/`-prefixed (e.g. `"/my_array"`);
  internal store keys are prefix strings without a leading slash
  (e.g. `"my_array/zarr.json"`).
- Zarr indexing is 0-based in the spec and in stored chunk keys; all
  R-facing APIs are 1-based.
- `chunk_grid_regular` and `chunk_grid_sharded` cache their IO objects
  per chunk/shard key in a `.chunk_map` environment to avoid repeated
  allocation.
- The `%||%` null-coalescing operator and `.size_string()`,
  `.protocol()`, `.buildNode()` helpers live in `R/utils.R`.
- `.build_codec_pipeline()` is a package-level utility that instantiates
  a codec list from raw metadata configuration; used by
  `array_builder$add_codec()` for sharding inner and index codec
  pipelines.
- Optional codecs (`zstd`, `gzip`, `crc32c`) require `qs2`, `zlib`, and
  `digest` respectively; `bit64` is required for sharded arrays. All are
  in `Suggests`, not `Imports`, checked with
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) at
  runtime.
- The synthetic sharded test store at
  `tests/testthat/testdata/sharded_test.zarr` was generated by
  `tests/testthat/testdata/make_sharded_store.py` using zarr-python. By
  default the store is zipped to avoid R complaining about files having
  the executable bit set. Regenerate it there if needed; do not attempt
  to write it from R (write support is not implemented).
