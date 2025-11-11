
<!-- README.md is generated from README.Rmd. Please edit that file -->

# zarr

<!-- badges: start -->

[![R-CMD-check](https://github.com/R-CF/zarr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/R-CF/zarr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`zarr` is a package to create and access Zarr stores using native R
code. This package implements a native R driver for `zarr` stores. It is
designed against the specification for Zarr core version 3.

## Basic usage

The easiest way to zarrify your data is simply to call `as_zarr()` on
your R vector, matrix or array.

``` r
library(zarr)

x <- array(1:400, c(5, 20, 4))
z <- as_zarr(x)
#> Loading required namespace: zlib
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
uses the “.zarr” extension.

``` r
fn <- tempfile(fileext = ".zarr")
z <- as_zarr(x, fn)
z
#> <Zarr>
#> Version   : 3 
#> Store     : Local file system store 
#> Location  : /var/folders/gs/s0mmlczn4l7bjbmwfrrhjlt80000gn/T//RtmpxaLnDf/filef9c71c796390.zarr 
#> Arrays    : 1 (single array store) 
#> Total size: 1.22 KB
```

Accessing data in a Zarr object is always through Zarr arrays identified
by name. When using function `as_zarr()` you don’t specify a name but
the Zarr object can only hold a single array, which is located at the
root `"/"` of the Zarr object.

``` r
# Get an array using list-like access on the Zarr object
arr <- z[["/"]]
arr
#> <Zarr array>  
#> Path     : / 
#> Data type: int32 
#> Shape    : 5 20 4 
#> Chunking : 5 20 4

# Index the Zarr array like a regular R array
# Indexes are 1-based, as usual in R (Zarr specifies everything as 0-based)
arr[1:2, 11:16, 3]
#>      [,1] [,2] [,3] [,4] [,5] [,6]
#> [1,]  251  256  261  266  271  276
#> [2,]  252  257  262  267  272  277

# ... including omitting dimensions ...
arr[, 1:5,1:2]
#> , , 1
#> 
#>      [,1] [,2] [,3] [,4] [,5]
#> [1,]    1    6   11   16   21
#> [2,]    2    7   12   17   22
#> [3,]    3    8   13   18   23
#> [4,]    4    9   14   19   24
#> [5,]    5   10   15   20   25
#> 
#> , , 2
#> 
#>      [,1] [,2] [,3] [,4] [,5]
#> [1,]  101  106  111  116  121
#> [2,]  102  107  112  117  122
#> [3,]  103  108  113  118  123
#> [4,]  104  109  114  119  124
#> [5,]  105  110  115  120  125

# ... and logical selections
d <- arr$shape
arr[1, which(seq(d[2]) <= 10), ]
#>       [,1] [,2] [,3] [,4]
#>  [1,]    1  101  201  301
#>  [2,]    6  106  206  306
#>  [3,]   11  111  211  311
#>  [4,]   16  116  216  316
#>  [5,]   21  121  221  321
#>  [6,]   26  126  226  326
#>  [7,]   31  131  231  331
#>  [8,]   36  136  236  336
#>  [9,]   41  141  241  341
#> [10,]   46  146  246  346
```

In this last example you will have noticed that the degenerate first
dimension was dropped. As in regular R, you have to explicitly indicate
it if you want to keep degenerate dimensions:

``` r
arr[1, which(seq(d[2]) <= 10), , drop = FALSE]
#> , , 1
#> 
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]    1    6   11   16   21   26   31   36   41    46
#> 
#> , , 2
#> 
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]  101  106  111  116  121  126  131  136  141   146
#> 
#> , , 3
#> 
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]  201  206  211  216  221  226  231  236  241   246
#> 
#> , , 4
#> 
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]  301  306  311  316  321  326  331  336  341   346
```

You can also write to a Zarr array, but the process is a bit more
complicated (due to a quirk in R):

``` r
arr$write(-99L, selection = list(2:3, 5:7, 1))
arr[, 1:10, 1]
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]    1    6   11   16   21   26   31   36   41    46
#> [2,]    2    7   12   17  -99  -99  -99   37   42    47
#> [3,]    3    8   13   18  -99  -99  -99   38   43    48
#> [4,]    4    9   14   19   24   29   34   39   44    49
#> [5,]    5   10   15   20   25   30   35   40   45    50
```

Two things of interest here:

1.  The data in the Zarr array is of type “int32”, the standard R
    integer. When writing data you should make sure that the object to
    be written is of the correct type, so using “-99L” here.
2.  The data is recycled (from a single value to 6 elements in the Zarr
    array) using normal R rules. Do note, however, that only single
    values are recycled and the “broadcasting” is per dimension of the
    Zarr array.

## Installation

You can install the development version of `zarr` from
[GitHub](https://github.com/) with:

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
