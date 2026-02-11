# Get a group or array from a Zarr group

This method can be used to retrieve a group or array from the Zarr group
by a relative path to the desired group or array.

## Usage

``` r
# S3 method for class 'zarr_group'
x[[i]]
```

## Arguments

- x:

  A `zarr_group` object to extract a group or array from.

- i:

  The path to a group or array in `x`. The path is relative to the
  group, it must not start with a slash "/". The path may start with any
  number of double dots ".." separated by slashes "/" to denote groups
  higher up in the hierarchy.

## Value

An instance of `zarr_group` or `zarr_array`, or `NULL` if the path is
not found.

## Examples

``` r
z <- create_zarr()
z$add_group("/", "tst")
#> <Zarr group> tst 
#> Path     : /tst 
z$add_group("/tst", "subtst")
#> <Zarr group> subtst 
#> Path     : /tst/subtst 
tst <- z[["/tst"]]
tst[["subtst"]]
#> <Zarr group> subtst 
#> Path     : /tst/subtst 
```
