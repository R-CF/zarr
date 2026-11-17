# Get a group or array from a Zarr object

This method can be used to retrieve a group or array from the Zarr
object by its path.

## Usage

``` r
# S3 method for class 'zarr'
x[[i]]

# S3 method for class 'zarr'
x[[i]] <- value
```

## Arguments

- x:

  A `zarr` object to extract a group or array from.

- i:

  The path to a group or array in `x`.

- value:

  The node at path `i`, i.e. the node returned by `x[[i]]`.

## Value

An instance of `zarr_group` or `zarr_array`, or `NULL` if the path is
not found.

## Details

Assignment with `[[<-` exists only so that chained assignments to a
field of a node, such as `z[["/t"]]$field <- value`, work: R assigns the
node back to `x` as the last step of such an expression. Nothing is
changed in `x`. An error is raised if `value` is not the very node at
path `i`; use the `add_group()` and `add_array()` methods to add nodes
to the hierarchy.

## Examples

``` r
z <- create_zarr()
z[["/"]]
#> ── Zarr group ☰ [root] ─────────────────────────────────────────────────────────
#> ℹ Path      : /
```
