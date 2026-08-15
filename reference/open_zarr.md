# Open a Zarr store

This function opens a Zarr object, connected to a store located on the
local file system or on a remote server using the HTTP or S3 protocol.
The Zarr object can be either v.2 or v.3.

## Usage

``` r
open_zarr(location, read_only = NULL, protocol = NULL, ...)
```

## Arguments

- location:

  Character string that indicates a location on a file system or a HTTP
  or S3 server where the Zarr store is to be found. The character string
  may contain UTF-8 characters and/or use a file URI format.

- read_only:

  Optional. Logical that indicates if the store is to be opened in
  read-only mode. Default is ` NULL`, which implies `FALSE` for a local
  file system store, `TRUE` otherwise.

- protocol:

  Optional, character string. Override automatic protocol detection
  ('local', 'http', or 's3'). Needed for S3-compatible endpoints that
  aren't AWS and don't follow AWS's hostname conventions (MinIO, EMBASSY
  Cloud, Ceph RGW, etc.) - there's no reliable way to recognize these
  from the URL alone, you have to indicate so explicitly rather than
  have `open_zarr()` parse the location.

- ...:

  Additional protocol-specific parameters passed through to the
  underlying store constructor. For `s3://` and S3 `https://` locations,
  this includes `region`, `profile`, `access_key`/`secret_key`/
  `session_token`, `endpoint`, and `anonymous` — see
  [zarr_s3store](https://r-cf.github.io/zarr/reference/zarr_s3store.md).
  Ignored for local and plain HTTP locations.

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
#> 
#> Attributes:
#> title      : CRU TS4.08 Mean Temperature
#> institution: Data held at British Atmospheric Data Centre, RAL, UK.
#> source     : Test data for the R zarr package
#> comment    : Do not use this data for any practical purpose other than testing the zarr package
#> contact    : https://github.com/R-CF/zarr/issues
```
