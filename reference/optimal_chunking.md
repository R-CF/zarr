# Get optimal chunking size for an array.

This function will determine the optimal chunking sizes of the array
dimensions based on weights per dimension.

## Usage

``` r
optimal_chunking(dim_sizes, weights, chunk_values = 4L * 1024L * 1024L)
```

## Arguments

- dim_sizes:

  Integer array of dimension lengths, corresponding to the `shape` of
  the array.

- weights:

  Optional, numeric vector with weights per dimension, in the same order
  as `dim_sizes`. If omitted, each dimension will have a weight of 1L,
  i.e. no preferential chunking on any dimension.

- chunk_values:

  Optional, integer value given the maximum number of array elements per
  chunk. Default is 4 million, meaning that the chunk size of `float32`
  data is at most 16MB uncompressed.

## Value

An integer vector with chunk length per dimension in the same order as
argument `dim_sizes`.

## Examples

``` r
shape <- c(x = 50000L, y = 350L, time = 8192)

# Default chunking, approaching the maximum chunk size
optimal_chunking(dim_sizes = shape)
#> [1] 161 175 161

# Prioritize extractions over the "time" dimension
optimal_chunking(dim_sizes = shape, weights = c(1, 1, 2))
#> [1]   46   44 2048
```
