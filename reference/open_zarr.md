# Open a Zarr store

This function opens a Zarr object, connected to a store located on the
local file system or on a remote server using the HTTP protocol. The
Zarr object can be either v.2 or v.3.

## Usage

``` r
open_zarr(location, read_only = FALSE)
```

## Arguments

- location:

  Character string that indicates a location on a file system or a HTTP
  server where the Zarr store is to be found. The character string may
  contain UTF-8 characters and/or use a file URI format.

- read_only:

  Optional. Logical that indicates if the store is to be opened in
  read-only mode. Default is `FALSE` for a local file system store,
  `TRUE` otherwise.

## Value

A [zarr](https://r-cf.github.io/zarr/reference/zarr.md) object.

## Examples

``` r
fn <- system.file("extdata", "africa.zarr", package = "zarr")
africa <- open_zarr(fn)
africa
#> <Zarr>
#> Version   : 3 
#> Store     : Local file system store 
#> Location  : /home/runner/work/_temp/Library/zarr/extdata/africa.zarr 
#> Arrays    : 1 
#> Total size: 540.36 KB 
#> Attributes:
#>  name        value                                             
#>  title       CRU TS4.08 Mean Temperature                       
#>  institution Data held at British Atmospheric Data Centre, R...
#>  source      Test data for the R zarr package                  
#>  comment     Do not use this data for any practical purpose ...
#>  contact     https://github.com/R-CF/zarr/issues               
```
