# Get a group or array from a Zarr object

This method can be used to retrieve a group or array from the Zarr
object by its path.

## Usage

``` r
# S3 method for class 'zarr'
x[[i]]
```

## Arguments

- x:

  A `zarr` object to extract a group or array from.

- i:

  The path to a group or array in `x`.

## Value

An instance of `zarr_group` or `zarr_array`, or `NULL` if the path is
not found.

## Examples

``` r
z <- create_zarr()
z[["/"]]
#> <Zarr group> [root] 
#> Path     : / 
```
