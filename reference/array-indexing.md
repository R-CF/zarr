# Extract or replace parts of a Zarr array

These operators can be used to extract or replace data from an array by
indices. Normal R array selection rules apply. The only limitation is
that the indices have to be consecutive.

## Usage

``` r
# S3 method for class 'zarr_array'
x[..., drop = TRUE]
```

## Arguments

- x:

  A `zarr_array` object of which to extract or replace the data.

- ...:

  Indices specifying elements to extract or replace. Indices are
  numeric, empty (missing) or `NULL`. Numeric values are coerced to
  integer or whole numbers. The number of indices has to agree with the
  dimensionality of the array.

- drop:

  If `TRUE` (the default), degenerate dimensions are dropped, if `FALSE`
  they are retained in the result.

## Value

When extracting data, a vector, matrix or array, having dimensions as
specified in the indices. When replacing part of the Zarr array, returns
`x` invisibly.

## Examples

``` r
x <- array(1:100, c(10, 10))
z <- as_zarr(x)
arr <- z[["/"]]
arr[3:5, 7:9]
#>      [,1] [,2] [,3]
#> [1,]   63   73   83
#> [2,]   64   74   84
#> [3,]   65   75   85
```
