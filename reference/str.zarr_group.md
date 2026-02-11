# Compact display of a Zarr group

Compact display of a Zarr group

## Usage

``` r
# S3 method for class 'zarr_group'
str(object, ...)
```

## Arguments

- object:

  A `zarr_group` instance.

- ...:

  Ignored.

## Examples

``` r
fn <- system.file("extdata", "africa.zarr", package = "zarr")
africa <- open_zarr(fn)
root <- africa[["/"]]
str(root)
#> Zarr group with 1 array and 0 sub-groups
```
