## Resubmission

This is a resubmission following manual review of a new package. This
resubmission addresses two points flagged by the reviewer:

* Quoting of names in the DESCRIPTION file: The `Zarr` specification that this
package implements is now quoted in the Title and Details section. The package
name is `zarr`, intentionally the lowercase version of the specification name.
* Writing files to the user file system: This package only writes to the local
file system following explicit function calls made by the user (e.g. calling
`create_zarr()`, `open_zarr()`, or `as_zarr()`) which includes a path on the
local file system where to write to, and populating the Zarr object with groups
and arrays in sub-directories of the initial path (which is effectively what
Zarr is about). The package does not do any other writing to the file system,
including to the current workspace or the user cache. Examples that write files
to disk all use `fn <- tempfile(fileext = ".zarr")` in combination with
`unlink(fn)`.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.
