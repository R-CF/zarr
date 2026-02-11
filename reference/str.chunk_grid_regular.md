# Compact display of a regular chunk grid

Compact display of a regular chunk grid

## Usage

``` r
# S3 method for class 'chunk_grid_regular'
str(object, ...)
```

## Arguments

- object:

  A `chunk_grid_regular` instance.

- ...:

  Ignored.

## Examples

``` r
fn <- system.file("extdata", "africa.zarr", package = "zarr")
africa <- open_zarr(fn)
tas <- africa[["/tas"]]
str(tas$chunking)
#> Zarr regular chunk grid: [80, 65, 12]
```
