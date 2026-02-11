# Convert an R object into a Zarr array

This function creates a Zarr object from an R vector, matrix or array.
Default settings will be taken from the R object (data type, shape).
Data is chunked into chunks of length 100 (or less if the array is
smaller) and compressed.

## Usage

``` r
as_zarr(x, name = NULL, location = NULL)
```

## Arguments

- x:

  The R object to convert. Must be a vector, matrix or array of a
  numeric or logical type.

- name:

  Optional. The name of the Zarr array to be created.

- location:

  Optional. If supplied, either an existing
  [zarr_group](https://r-cf.github.io/zarr/reference/zarr_group.md) in a
  Zarr object, or a character string giving the location on a local file
  system where to persist the data. If the argument is a `zarr_group`,
  argument `name` must be provided. If the argument gives the location
  for a new Zarr store then the location must be writable by the calling
  code. As per the Zarr specification, it is recommended to use a
  location that ends in ".zarr" when providing a location for a new
  store. If argument `name` is given then the Zarr array will be created
  in the root of the Zarr store with that name. If the `name` argument
  is not given, a single-array Zarr store will be created. If the
  `location` argument is not given, a Zarr object is created in memory.

## Value

If the `location` argument is a `zarr_group`, the new Zarr array is
returned. Otherwise, the Zarr object that is newly created and which
contains the Zarr array, or an error if the Zarr object could not be
created.

## Examples

``` r
x <- array(1:400, c(5, 20, 4))
z <- as_zarr(x)
z
#> <Zarr>
#> Version   : 3 
#> Store     : memory store 
#> Arrays    : 1 (single array store) 
```
