# 1. Zarr for R

## Zarr

Zarr is a widely used format for the storage and retrieval of
n-dimensional array data from data stores ranging from local file
systems to the cloud. This package is a native Zarr implementation in R
with support for all required features of Zarr version 3. It can also
read Zarr version 2 stores.

## Creating Zarr objects

Creating a new Zarr object is very easy:

``` r

library(zarr)

z <- create_zarr()
z
#> ── Zarr ────────────────────────────────────────────────────────────────────────
#> ── Memory store - version 3 ────────────────────────────────────────────────────
#> ✔ Listing ✔ Writing ✔ Deleting ✖ Consolidated metadata
#> ── Contents ────────────────────────────────────────────────────────────────────
#> ℹ Arrays: 0

# The root group in the Zarr object
z[["/"]]
#> ── Zarr group ☰ [root] ─────────────────────────────────────────────────────────
#> ℹ Path      : /
```

With
[`create_zarr()`](https://r-cf.github.io/zarr/reference/create_zarr.md)
you create a new Zarr object as a Zarr store in memory. The Zarr object
will have a root group to which you can add other groups and arrays, or
metadata in the form of attributes (see `vignette("03_attributes")` for
details). Groups organize the Zarr object contents in a hierarchy not
unlike directories and files on the disk in your computer. You may add
as many groups as your data requires to any other group:

``` r

# Add a group directly to the Zarr object
grp1 <- z$add_group(path = "/", name = "first_group")
grp2 <- z$add_group(path = "/", name = "second_group")

# Path can be compound
z$add_group(path = "/second_group", name = "grp2_subgroup")
#> ── Zarr group ☰ grp2_subgroup ──────────────────────────────────────────────────
#> ℹ Path      : /second_group/grp2_subgroup

# Add sub-groups directly to a group
grp1$add_group(name = "grp1_subgroup")
#> ── Zarr group ☰ grp1_subgroup ──────────────────────────────────────────────────
#> ℹ Path      : /first_group/grp1_subgroup

# Names may use the UTF-8 encoding
grp1$add_group(name = "กลุ่มย่อย") # = subgroup in Thai
#> ── Zarr group ☰ กลุ่มย่อย ─────────────────────────────────────────────────────────
#> ℹ Path      : /first_group/กลุ่มย่อย

# The hierarchy of groups
z$hierarchy()
#> ── Zarr hierarchy  ─────────────────────────────────────────────────────────────
#> ☰ / (root group)
#>   ☰ first_group
#>     ☰ grp1_subgroup
#>     ☰ กลุ่มย่อย
#>   ☰ second_group
#>     ☰ grp2_subgroup
```

Group names may use UTF-8 encoded strings. This means that a large
number of languages is supported, including Latin-based languages
(`øßñğłþéèçàôãœčšžđńęř` all work), Cyrillic (`Дяћѝюѯ`) and most Asian
languages.

## Persistent Zarr objects

In many cases you will want to persist your Zarr data to disk. This can
be achieved by supplying a location on a file system when creating the
Zarr object. This location should not already exist and it will become a
Zarr store: a directory, with sub-directories for any added groups and
arrays. It is recommended that the name of the location has a “.zarr”
extension so that it is easily recognizable as such.

``` r

# Here we use a temporary file
fn <- tempfile(fileext = ".zarr")

# Create the Zarr object on disk
z <- create_zarr(location = fn)
z
#> ── Zarr ────────────────────────────────────────────────────────────────────────
#> ── Local file system store - version 3 ─────────────────────────────────────────
#> ✔ Listing ✔ Writing ✔ Deleting ✖ Consolidated metadata
#> ℹ Location  : /tmp/RtmpGzA3En/file1f0333807d6a.zarr
#> ℹ Total size: 47 Bytes
#> ── Contents ────────────────────────────────────────────────────────────────────
#> ℹ Arrays: 0
```

The 47 bytes of storage are taken up by a “zarr.json” file. Every
directory in a Zarr store has such a file that identifies the directory
as a Zarr group or Zarr array. For Zarr arrays the “zarr.json” file is
much bigger, and for groups files there can also be added attributes
increasing the file size.

After you have created the Zarr store on disk you can create groups and
arrays just as with a memory Zarr store.

Opening a Zarr store from file is done with
[`open_zarr()`](https://r-cf.github.io/zarr/reference/open_zarr.md),
giving the location of the Zarr store on disk.

``` r

unlink(fn)
```

### Saving to another Zarr store

You can save an entire `zarr` object to a new Zarr store using the
`zarr$save_to()` method. This method copies the entire hierarchy with
all objects from the source `zarr` object to a new Zarr store. Typically
that would be on a local file system but it could also be to a S3 server
if you have the credentials for writing there. This operation has a few
well-defined purposes:

- **Persist a memory Zarr store to disk:** While working on your data
  and repeatedly modifying array data, it is often faster to use a
  memory Zarr store, assuming it fits in your computer’s RAM. Once you
  have the final product you can persist it to disk.
- **Convert a Zarr v.2 store to version 3:** The `zarr` package uses the
  Zarr version 3 specification internally so all writing is done using
  the v.3 formatting.
- **Get a local copy of an online Zarr store:** You can open an online
  Zarr store and then save to a local disk. Make sure you know the size
  of the Zarr store before you do this (printing the online `zarr`
  object to the console will tell you) because Zarr stores may be huge
  and exhaust your disk space, or you may run into server-side limits on
  data transfers.

### Other Zarr stores

Currently, this package supports local file system stores, online HTTP
and S3 stores and memory stores. Support for other stores may be added
in the future.

## Customisation

The `zarr` package uses a number of options to control processing of
data.

| Option | Type | Default value | Reasonable values | Description |
|:---|:--:|:--:|:--:|:---|
| min_compress | integer | 100 | 0 - 10000 | Compressing small chunks of data is inefficient as it does not save much space but it does incur the processing overhead of compression and decompression. This setting gives the smallest chunk size that will be compressed upon writing. |
| chunk_length | integer | 100 | 100 - 10000 | The maximum length of a chunk, along each dimension of the array, before the dimension is broken up. This is used for cases where there is no additional information to guide the chunking; the [`optimal_chunking()`](https://r-cf.github.io/zarr/reference/optimal_chunking.md) function, for instance, will not use this option. |
| eps | numeric | 1.49e-08 | Several magnitudes smaller than typical data | Tolerance value to determine if two numeric values are considered to be the same. Default is equal to `.Machine$double.eps^0.5`. |
| parallel_threshold | integer | 20 | 4 - 30 | Minimum number of chunks to be read before parallel processing is used, if a suitable plan is set. |
| chunk_cache_bytes | integer | 64MB | 0 - 25% of RAM | The size of the chunk cache before chunks get swapped out. Caching chunks makes multiple reads and writes to a single chunk much more efficient so the optimal size depends on the use scenario. Chunks that get read or written repeatedly (e.g. stream data to an array one time step per write) benefit from a larger cache. |

### Printing

If package `cli` is installed (as is the case in RStudio by default), it
will be used to print object properties to the console or other
supported document types (such as the articles on this site). Themes
will be constructed from 5 styles that can be set by the user, using the
options available in the `cli` package, in particular in the
[`make_ansi_style()`](https://cli.r-lib.org/reference/make_ansi_style.html)
function.

| Option | Default value | Description |
|:---|:--:|:---|
| group_style | `c("blue", "bold")` | Used for names of groups. |
| array_style | `c("green", "bold")` | Used for names of arrays. |
| label_style | `c("black", "bold")` | Used for general labels, including attribute names. |
| text_style | `"blue"` | Used for general text, group and array properties and attribute values. |
| minor_style | `"grey"` | Used for details of minor importance. |

These styles can be modified like any other option. It should be noted
that styles and themes require careful management (start using a theme,
end use of a theme) which is easy to get wrong (this is a `cli` issue).
If you find your styles are not being applied properly, reload this
package. If that still does not fix the issue, try repeated `cli_end()`
calls. As a last resort you may have to restart the R session. In
general use of this package those problems should not occur, but if you
start experimenting with styles issues may arise during development and
testing.

### Querying and modifying options

Most options can be examined or modified by the user using the
[`zarr_options()`](https://r-cf.github.io/zarr/reference/zarr_options.md)
function. Without any arguments the function will list all the options
with their values. If the `key` argument is provided, the value of the
corresponding option is returned. If both `key` and `value` arguments
are provided, the corresponding option will be set, if the `value` is
reasonable. Bad arguments will be silently dropped and no option will be
modified.

### Persisting options

You may save modified options by calling the
[`save_options()`](https://r-cf.github.io/zarr/reference/save_options.md)
functions. This will create a small RDS file in your `config` directory.
In subsequent sessions the RDS file will be read automatically and the
options will be used. You can “forget” about modified options and revert
to the package defaults by calling
[`reset_options()`](https://r-cf.github.io/zarr/reference/reset_options.md).
