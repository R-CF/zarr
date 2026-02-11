# 1. Zarr for R

## Zarr

Zarr is a widely used format for the storage and retrieval of
n-dimensional array data from data stores ranging from local file
systems to the cloud. This package is a native Zarr implementation in R
with support for all required features of Zarr version 3.

## Creating Zarr objects

Creating a new Zarr object is very easy:

``` r
library(zarr)

z <- create_zarr()
z
#> <Zarr>
#> Version   : 3 
#> Store     : memory store 
#> Arrays    : 0

# The root group in the Zarr object
z[["/"]]
#> <Zarr group> [root] 
#> Path     : /
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
#> <Zarr group> grp2_subgroup 
#> Path     : /second_group/grp2_subgroup

# Add sub-groups directly to a group
grp1$add_group(name = "grp1_subgroup")
#> <Zarr group> grp1_subgroup 
#> Path     : /first_group/grp1_subgroup

# Names may use the UTF-8 encoding
grp1$add_group(name = "กลุ่มย่อย") # = subgroup in Thai
#> <Zarr group> กลุ่มย่อย 
#> Path     : /first_group/กลุ่มย่อย

# The hierarchy of groups
z$hierarchy()
#> <Zarr hierarchy> 
#> ☰ / (root group)
#> ├ ☰ first_group
#> │ ├ ☰ grp1_subgroup
#> │ └ ☰ กลุ่มย่อย
#> └ ☰ second_group
#>   └ ☰ grp2_subgroup
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
#> <Zarr>
#> Version   : 3 
#> Store     : Local file system store 
#> Location  : /tmp/RtmplloNBy/file1dd43a14cf10.zarr 
#> Arrays    : 0 
#> Total size: 47 Bytes
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

## Other Zarr stores

Currently, this package supports local file system stores, online HTTP
stores and memory stores. Support for cloud-based stores will be added
in the near future.
