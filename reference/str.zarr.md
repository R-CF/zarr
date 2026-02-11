# Compact display of a Zarr object

Compact display of a Zarr object

## Usage

``` r
# S3 method for class 'zarr'
str(object, ...)
```

## Arguments

- object:

  A `zarr` instance.

- ...:

  Ignored.

## Examples

``` r
fn <- system.file("extdata", "africa.zarr", package = "zarr")
africa <- open_zarr(fn)
str(africa)
#> Zarr object with 1 array
```
