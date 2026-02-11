# Compact display of a Zarr array

Compact display of a Zarr array

## Usage

``` r
# S3 method for class 'zarr_array'
str(object, ...)
```

## Arguments

- object:

  A `zarr_array` instance.

- ...:

  Ignored.

## Examples

``` r
fn <- system.file("extdata", "africa.zarr", package = "zarr")
africa <- open_zarr(fn)
tas <- africa[["/tas"]]
str(tas)
#> Zarr array: [float32] shape [160, 260, 12] chunk [80, 65, 12]
```
