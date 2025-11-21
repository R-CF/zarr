
<!-- README.md is generated from README.Rmd. Please edit that file -->

# zarr

<!-- badges: start -->

[![R-CMD-check](https://github.com/R-CF/zarr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/R-CF/zarr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`zarr` is a package to create and access Zarr stores using native R
code. It is designed against the specification for Zarr core version 3.

## Basic usage

The easiest way to zarrify your data is simply to call `as_zarr()` on
your R vector, matrix or array.

``` r
library(zarr)

x <- array(1:400, c(5, 20, 4))
z <- as_zarr(x)
#> Loading required namespace: blosc
z
#> <Zarr>
#> Version   : 3 
#> Store     : memory store 
#> Arrays    : 1 (single array store)
```

This uses information from the array (data type, dimensions) in
combination with default Zarr settings (chunk size, data layout,
compression). `z` is an in-memory `zarr` object consisting of a single
array, with the R object broken up into chunks (if the dimensions are
substantially large enough to warrant that) and compressed.

If you prefer to persist your R object to file, provide a location where
you want to store the data. It is recommended that the name of the store
uses the “.zarr” extension. At the same time you may give your Zarr
array a name that you can later use to retrieve the array and its data.

``` r
fn <- tempfile(fileext = ".zarr")
z <- as_zarr(x, name = "my_array", location = fn)
z
#> <Zarr>
#> Version   : 3 
#> Store     : Local file system store 
#> Location  : /var/folders/gs/s0mmlczn4l7bjbmwfrrhjlt80000gn/T//RtmpoFaubn/file78f3424d7023.zarr 
#> Arrays    : 1 
#> Total size: 1.09 KB
```

The total size that is printed to the console when inspecting a Zarr
object sums up the size of both types of files in the root directory and
any sub-directories.

##### Reading and writing Zarr arrays

You can access the data in a Zarr object through its arrays. If you
didn’t specify a name when using function `as_zarr()`, the Zarr object
can only hold a single array, which is located at the root `"/"` of the
Zarr object. If you did specify a name you should indicate the full path
starting with a slash `"/"` for the root:

``` r
# Get the array using list-like access on the Zarr object
arr <- z[["/my_array"]]
arr
#> <Zarr array> my_array 
#> Path      : /my_array 
#> Data type : int32 
#> Shape     : 5 20 4 
#> Chunking  : 5 20 4

# Index the Zarr array like a regular R array
# Indexes are 1-based, as usual in R (Zarr specifies everything as 0-based)
arr[1:2, 11:16, 3]
#>      [,1] [,2] [,3] [,4] [,5] [,6]
#> [1,]  251  256  261  266  271  276
#> [2,]  252  257  262  267  272  277
```

You can also write to a Zarr array, but the process is a bit more
complicated (due to a quirk in R):

``` r
arr$write(-99L, selection = list(2:3, 5:7, 1))
arr$write(NA_integer_, selection = list(1:5, 1, 1))
arr[, 1:10, 1]
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]   NA    6   11   16   21   26   31   36   41    46
#> [2,]   NA    7   12   17  -99  -99  -99   37   42    47
#> [3,]   NA    8   13   18  -99  -99  -99   38   43    48
#> [4,]   NA    9   14   19   24   29   34   39   44    49
#> [5,]   NA   10   15   20   25   30   35   40   45    50
```

The data in the Zarr array is of type “int32”, the standard R integer.
When writing data you should make sure that the object to be written is
of the correct type, so using “-99L” and “NA_integer\_” here. Numeric
data is stored by default as “float64”, logical data as “int8”.

## Installation

Installation from CRAN of the latest release:

    install.packages("zarr")

You can install the development version of `zarr` from
[GitHub](https://github.com/R-CF/zarr) with:

    # install.packages("devtools")
    devtools::install_github("R-CF/zarr")

## Development

This package is in the early phases of development and should not be
used for production environments. Things may fail and you are advised to
ensure that you have backups of all data that you put in a Zarr store
with this package.

Like Zarr itself, this package is modular and allows for additional
stores, codes, transformers and extensions to be added to this basic
implementation. If you have specific needs, open an [issue on
Github](https://github.com/R-CF/zarr/issues) or, better yet, fork the
code and submit code suggestions via a pull request. Specific guidance
for developers is being drafted.
