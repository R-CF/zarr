# Create a Zarr store

This function creates a Zarr v.3 instance, with a store located on the
local file system. The root of the Zarr store will be a group to which
other groups or arrays can be added.

## Usage

``` r
create_zarr(location)
```

## Arguments

- location:

  Character string that indicates a location on a file system where the
  data in the Zarr object will be persisted in a Zarr store in a
  directory. The character string may contain UTF-8 characters and/or
  use a file URI format. The Zarr specification recommends that the
  location use the ".zarr" extension to identify the location as a Zarr
  store.

## Value

A [zarr](https://r-cf.github.io/zarr/reference/zarr.md) object.

## Examples

``` r
fn <- tempfile(fileext = ".zarr")
my_zarr_object <- create_zarr(fn)
my_zarr_object$store$root
#> [1] "/tmp/RtmpG7seZt/file1bb11cd7cf5d.zarr"
unlink(fn)
```
