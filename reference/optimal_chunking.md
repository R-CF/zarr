# Get optimal chunking size for an array.

This function will determine the optimal chunking sizes of the array
dimensions based on weights per dimension.

## Usage

``` r
optimal_chunking(dim_sizes, groups, weights, chunk_values = 4L * 1024L * 1024L)
```

## Arguments

- dim_sizes:

  Named integer array of dimension lengths, corresponding to the `shape`
  of the array.

- weights:

  Optional, numeric vector with weights per dimension. If omitted, each
  dimension will have a weight of 1L, i.e. no preferential chunking on
  any dimension.

- chunk_values:

  Optional, integer value given the maximum number of array elements per
  chunk. Default is 4 million, meaning that the chunk size of `float32`
  data is at most 16MB uncompressed.

## Value

An integer vector with chunk length per group or dimension.

## Examples

``` r
shape <- c(x = 50000L, y = 350L, time = 8192)

# Default chunking, approaching the maximum chunk size
optimal_chunking(dim_sizes = shape)
#>    x    y time 
#>  161  175  161 

# Prioritize extractions over the "time" dimension
optimal_chunking(dim_sizes = shape, weights = c(1, 1, 2))
#>    x    y time 
#>   46   44 2048 

# Prioritize extractions over the grouped "x" and "y" dimensions
optimal_chunking(dim_sizes = shape,
                 groups = list(c("x", "y"), "time"),
                 weights = c(1.3, 1))
#>    x    y time 
#>   74   70  745 
```
