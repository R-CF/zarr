# Optimal chunking for an array

This function computes the optimal dimension lengths of a single chunk
from the array dimensions as given in argument `dims`. "Optimal" means
that the provided solution is as close as possible to the `max_chunk`
size.

## Usage

``` r
auto_chunk(dims, max_chunk = Zarr.options$chunk_length)
```

## Arguments

- dims:

  Integer array with the lengths along every dimension of the array.

- max_chunk:

  Optional. Integer giving the maximum number of elements per chunk.
  Defaults to `Zarr.options$chunk_length`.

## Value

An integer array with the same length as argument `dims` giving the
length of a chunk along each dimension of the array.

## Examples

``` r
shape <- c(5000L, 43L, 12800L, 4L)
auto_chunk(shape)
#> [1] 100  43 100   4
auto_chunk(shape, 10000L)
#> [1] 5000   43 6400    4
```
