# 4. HTTP stores

The `zarr` package can read online stores over HTTP, meaning that Zarr
stores published on a regular web site are accessible. Access is
read-only. Unfortunately, there is no uniform mechanism to identify what
Zarr arrays are published and where they are located on the web site.
This package supports three mechanisms to access HTTP stores.

## Accessing HTTP stores

### Zarr v.2: Consolidated metadata

Zarr v.2 supports consolidated metadata, a JSON file called `.zmetadata`
in the root of the HTPP store which lists all the groups and arrays
present in the store. When a `.zmetadata` file is present, it will be
automatically read and groups and arrays will be added to the `zarr`
object to represent the contents of the HTTP store.

``` r
# Publicly accessible Zarr v.2 HTTP store with consolidated metadata
z <- open_zarr("https://data.earthdatahub.destine.eu/public/test-dataset-v0.zarr")
#> Loading required namespace: curl
z$hierarchy()
#> <Zarr hierarchy> https://data.earthdatahub.destine.eu/public/test-dataset-v0.zarr 
#> ☰ / (root group)
#> ├ ⌗ age_band_lower_bound
#> ├ ⌗ demographic_totals
#> ├ ⌗ latitude
#> ├ ⌗ longitude
#> └ ⌗ year
```

### Single-array store

If there is no consolidated metadata, the HTTP store will be queried for
a `zarr.json` (v.3) or `.zarray` (v.2) JSON file, containing the
description of a single Zarr array. If found, the array will added to
the `zarr` object. The array may have attributes that describe the
properties of the array, such as coordinates of the axes. These
attributes have to be examined manually; the Zarr specification has no
standards for attribute contents.

``` r
z <- open_zarr("https://raw.githubusercontent.com/R-CF/zarr/main/inst/extdata/africa.zarr/tas")
z[["/"]]
#> <Zarr array>  
#> Path      : / 
#> Data type : float32 
#> Shape     : 160 260 12 
#> Chunking  : 80 65 12 
#> Attributes:
#>  name      value                   
#>  long_name near-surface temperature
#>  units     degrees Celsius
```

The downside of this approach is that you need to have knowledge of the
Zarr resource to be able to properly interpret the data.

### Group

When there is no consolidated metadata or a single array at the root of
the HTTP store, a group is expected as the final option. The group
should have attributes that explain what is contained in the store.

The below example uses sample data from the [Open Microscopy
Environment](https://www.openmicroscopy.org) (OME) who have published
the [OME-Zarr
specification](https://ngff.openmicroscopy.org/specifications/index.html)
for Zarr stores. You need to understand that specification to interpret
the data.

``` r
# A publicly accessible OME-Zarr data set
(z <- open_zarr("https://uk1s3.embassy.ebi.ac.uk/idr/zarr/v0.4/idr0044A/4007801.zarr"))
#> <Zarr>
#> Version   : 2 
#> Store     : HTTP store 
#> Arrays    : 0 
#> Attributes:
#>  name        value                                             
#>  _creator    omero-zarr, 0.3.0                                 
#>  multiscales list(axes = list(list(name = "t", type = "time"...
#>  omero       list(list(active = TRUE, coefficient = 1, color...

# The attribute "multiscales" indicates the details of the data sets in the store
# The "path" element is the path to the individual arrays
jsonlite::prettify(jsonlite::toJSON(z$root$attributes[["multiscales"]], auto_unbox = TRUE))
#> [
#>     {
#>         "axes": [
#>             {
#>                 "name": "t",
#>                 "type": "time"
#>             },
#>             {
#>                 "name": "c",
#>                 "type": "channel"
#>             },
#>             {
#>                 "name": "z",
#>                 "type": "space",
#>                 "unit": "micrometer"
#>             },
#>             {
#>                 "name": "y",
#>                 "type": "space",
#>                 "unit": "micrometer"
#>             },
#>             {
#>                 "name": "x",
#>                 "type": "space",
#>                 "unit": "micrometer"
#>             }
#>         ],
#>         "datasets": [
#>             {
#>                 "coordinateTransformations": [
#>                     {
#>                         "scale": [
#>                             1,
#>                             1,
#>                             1,
#>                             1,
#>                             1
#>                         ],
#>                         "type": "scale"
#>                     }
#>                 ],
#>                 "path": "0"
#>             },
#>             {
#>                 "coordinateTransformations": [
#>                     {
#>                         "scale": [
#>                             1,
#>                             1,
#>                             1,
#>                             2,
#>                             2
#>                         ],
#>                         "type": "scale"
#>                     }
#>                 ],
#>                 "path": "1"
#>             },
#>             {
#>                 "coordinateTransformations": [
#>                     {
#>                         "scale": [
#>                             1,
#>                             1,
#>                             1,
#>                             4,
#>                             4
#>                         ],
#>                         "type": "scale"
#>                     }
#>                 ],
#>                 "path": "2"
#>             },
#>             {
#>                 "coordinateTransformations": [
#>                     {
#>                         "scale": [
#>                             1,
#>                             1,
#>                             1,
#>                             8,
#>                             8
#>                         ],
#>                         "type": "scale"
#>                     }
#>                 ],
#>                 "path": "3"
#>             },
#>             {
#>                 "coordinateTransformations": [
#>                     {
#>                         "scale": [
#>                             1,
#>                             1,
#>                             1,
#>                             16,
#>                             16
#>                         ],
#>                         "type": "scale"
#>                     }
#>                 ],
#>                 "path": "4"
#>             }
#>         ],
#>         "metadata": {
#>             "method": "loci.common.image.SimpleImageScaler",
#>             "version": "Bio-Formats 6.9.1"
#>         },
#>         "version": "0.4"
#>     }
#> ]
#> 

# Open the array at path "3"
z3 <- open_zarr("https://uk1s3.embassy.ebi.ac.uk/idr/zarr/v0.4/idr0044A/4007801.zarr/3")
z3[["/"]]
#> <Zarr array>  
#> Path      : / 
#> Data type : uint16 
#> Shape     : 532 2 988 256 271 
#> Chunking  : 1 1 1 256 271
```

## Authentication

This package does not manage authentication for web resources.
Authentication comes in many different forms, including
supplier-specific protocols, and it is impossible to cater to them all.
More basic forms of authentication may use HTTP session tokens that are
inserted in the URL. If that is the case, you should manually get a
session token and then insert it into the URL that is used to open the
store in `zarr`.

For more complicated cases, it may be useful to write a small package on
top of `zarr` to manage authentication. We’d love to hear of your
efforts!

## Working with array data from a HTTP store

You can work with array data just like you would be array data from a
file system store: index it like any other R array. Keep in mind,
though, that the data will be fetched over your internet connection so
be very judicious in your indexing. Downloading a full array is almost
always a bad idea as Zarr arrays tend to be large. In the OME-Zarr
example above, there are `532 * 2 * 988 * 256 * 271 = 72930271232` grid
points, which expands to about 271GB of integer data in R!

A more intelligent way to download data is to look at the chunking of
the array data. From the “axes” array in the “multiscales” attribute we
can see that a chunk (the unit of downloading data) is all of the “x”
and “y” extent for a single “\[z, c, t\]” tuple. The most efficient way
of downloading the data is then to follow the chunking scheme and
download one or a few of the “z”, “c” and “t” values and all of “x” and
“y”.
