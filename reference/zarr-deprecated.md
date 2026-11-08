# Deprecated functions in package zarr

These functions are provided for compatibility with older versions of
`zarr` only, and will be removed in a future release.

- `auto_chunk()`: use
  [`optimal_chunking()`](https://r-cf.github.io/zarr/reference/optimal_chunking.md)
  instead. `auto_chunk()` limits the chunk length along each dimension
  separately, which does not control the size of a chunk.
  [`optimal_chunking()`](https://r-cf.github.io/zarr/reference/optimal_chunking.md)
  targets a number of values per chunk. Deprecated November 2026,
  defunct May 2027, removed November 2027.

## Usage

``` r
auto_chunk(dims, max_chunk = Zarr.options$chunk_length)
```

## Arguments

- dims:

  Integer vector with the lengths along every dimension of the array.

- max_chunk:

  Optional. Integer giving the maximum length of a chunk along each
  dimension. Defaults to `zarr_options("chunk_length")`.

## Value

`auto_chunk()`: an integer vector with the same length as argument
`dims` giving the length of a chunk along each dimension of the array.
