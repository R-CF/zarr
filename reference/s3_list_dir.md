# List objects/prefixes in an S3 bucket

Lists the immediate contents under a prefix in an S3 bucket, without
requiring a valid Zarr store to be present at that prefix. Useful for
discovering the actual store path(s) within a bucket that hosts multiple
datasets, before calling
[`open_zarr()`](https://r-cf.github.io/zarr/reference/open_zarr.md) or
`zarr_s3store$new()`.

## Usage

``` r
s3_list_dir(
  bucket,
  prefix = "",
  region = NULL,
  profile = NULL,
  access_key = NULL,
  secret_key = NULL,
  session_token = NULL,
  endpoint = NULL,
  path_style = NULL,
  anonymous = NULL
)
```

## Arguments

- bucket:

  Character string. The S3 bucket name.

- prefix:

  Character string. The prefix to list under. Default `""`.

- region, profile, access_key, secret_key, session_token, endpoint,
  anonymous, path_style:

  As in
  [zarr_s3store](https://r-cf.github.io/zarr/reference/zarr_s3store.md);
  same credential resolution and anonymous default.

## Value

A character vector of keys/prefixes found immediately below `prefix`.

## Examples

``` r
# OME test data
(prefix <- s3_list_dir("ome-zarr-scivis", region = "us-east-1"))
#> [1] "v0.4/" "v0.5/"
```
