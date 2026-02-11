# 2. Working with arrays

If you are working with Zarr, you want to store your data in a compact
manner that is easy to use, with persistence between R sessions and
portable to other environments. In this article we’ll show you how to
create Zarr arrays, how to load data into them and how to read the data
back into your (future) R session.

> When we are referring to “arrays” we’ll be explicit about what we are
> talking about: a “Zarr array” is a data structure in a “Zarr object”.
> This is to avoid confusion with the “R array”. Note that a Zarr array
> can store an R array but also a matrix or a vector.

## Quick start

The easiest way to create a Zarr object is to simply “cast” your R
object to a Zarr object.

``` r
library(zarr)

x <- 1:500

z <- as_zarr(x)
z
#> <Zarr>
#> Version   : 3 
#> Store     : memory store 
#> Arrays    : 1 (single array store)
```

This creates a Zarr array in memory from an R vector of integers with a
length of 500. The two vector properties *mode* and *length* are used to
define the Zarr array, in combination with some default Zarr settings
such as for the chunking and the compression.

In general it is more useful to persist your data to a Zarr “store”. The
store is a directory on your local file system and you can put multiple
Zarr arrays in one Zarr store, using a directory hierarchy of Zarr
groups. These Zarr stores are identified by the presence of a
“zarr.json” file, one for each Zarr group and array, a JSON document
that defines what is contained in the directory. These Zarr stores can
be used to persist data between R sessions, for instance as an
alternative to “.Rdata” files.

``` r
x <- array(1:10000, c(500, 10, 2))

# Create a Zarr array from an R array, with a name for the array
# and persisted to the local file system
fn <- tempfile(fileext = ".zarr")
z <- as_zarr(x, name = "top_array", location = fn)
z
#> <Zarr>
#> Version   : 3 
#> Store     : Local file system store 
#> Location  : /tmp/RtmpgwyEfw/file1e0d426c6eeb.zarr 
#> Arrays    : 1 
#> Total size: 2.91 KB
z$hierarchy()
#> <Zarr hierarchy> /tmp/RtmpgwyEfw/file1e0d426c6eeb.zarr 
#> ☰ / (root group)
#> └ ⌗ top_array
```

If you have multiple R objects that you want to store in the Zarr
format, you can place them all in the same store. Adding an R object to
an existing store requires you to indicate the group in the Zarr object
where you want to store the R object.

``` r
# Some R objects
v <- runif(500)
w <- matrix(nrow = 5, ncol = 3)

# Get the root group from the Zarr object and put one R object there
grp <- z[["/"]]
arr <- as_zarr(v, name = "a_vector", location = grp)

# Make a sub-group in the Zarr object, for our Japanese developers
# UTF-8 is allowed in group and array names
grp <- z$add_group(path = "/", name = "サブグループ")  # = subgroup
arr <- as_zarr(w, name = "空の行列", location = grp)  # = empty matrix
z$hierarchy()
#> <Zarr hierarchy> /tmp/RtmpgwyEfw/file1e0d426c6eeb.zarr 
#> ☰ / (root group)
#> ├ ⌗ top_array
#> ├ ⌗ a_vector
#> └ ☰ サブグループ
#>   └ ⌗ 空の行列
```

Directories with Zarr arrays have data files with names like `c.1.0.0`,
usually compressed to save disk space. (The chunks may also be stored in
directory trees, like `c/1/0` with the chunk in files like `0`, `1`,
`2`, …)

``` r
list.files(path = z$store$root, recursive = TRUE)
#>  [1] "a_vector/c.0"                    "a_vector/c.1"                   
#>  [3] "a_vector/c.2"                    "a_vector/c.3"                   
#>  [5] "a_vector/c.4"                    "a_vector/zarr.json"             
#>  [7] "top_array/c.0.0.0"               "top_array/c.1.0.0"              
#>  [9] "top_array/c.2.0.0"               "top_array/c.3.0.0"              
#> [11] "top_array/c.4.0.0"               "top_array/zarr.json"            
#> [13] "zarr.json"                       "サブグループ/zarr.json"         
#> [15] "サブグループ/空の行列/zarr.json"
z
#> <Zarr>
#> Version   : 3 
#> Store     : Local file system store 
#> Location  : /tmp/RtmpgwyEfw/file1e0d426c6eeb.zarr 
#> Arrays    : 3 
#> Total size: 7.67 KB
unlink(fn)
```

A couple of things to note:

- The total size that is printed to the console when inspecting a Zarr
  object sums up the size of both types of files in the root directory
  and any sub-directories. Note that the compression here is
  spectacular: 10,000 integers in the R array `x` take up 40,000 bytes,
  vector `v` and matrix `w` another 4,120 bytes. Inclusive of the
  non-compressed JSON files, the Zarr store takes up only a small
  fraction of that.
- By default, R objects are broken up into chunks of length 100 along
  each dimension of the R object. Vector `v` thus has chunks named
  `c.0`, `c.1`, `c.2`, `c.3`, `c.4`. Array `x` has three dimensions, so
  the names are like `c.0.0.0`. The indices for the chunks names are
  0-based, a requirement from the Zarr specification. Note that our
  Japanese Zarr array `/サブグループ/空の行列` does not have any data
  files at all: matrix `w` was created with `data = NA` and chunks with
  only `NA` values are not written to disk for added efficiency.

## Creating your own Zarr arrays

You can define your own Zarr arrays with full control over the
parameters to be used. A special utility class, `array_builder`, helps
you construct a valid “zarr.json” metadata document that you need when
creating the Zarr array.

``` r
arr_def <- define_array(data_type = "int16", shape = c(240, 310, 5))
arr_def
#> <Zarr array metadata> VALID 
#> {
#>   "zarr_format": 3,
#>   "node_type": "array",
#>   "shape": [240, 310, 5],
#>   "data_type": "int16",
#>   "fill_value": -32767,
#>   "chunk_grid": {
#>     "name": "regular",
#>     "configuration": {
#>       "chunk_shape": [100, 100, 5]
#>     }
#>   },
#>   "codecs": {
#>     "transpose": {
#>       "name": "transpose",
#>       "configuration": {
#>         "order": [2, 1, 0]
#>       }
#>     },
#>     "bytes": {
#>       "name": "bytes",
#>       "configuration": {
#>         "endian": "little"
#>       }
#>     },
#>     "blosc": {
#>       "name": "blosc",
#>       "configuration": {
#>         "level": 6,
#>         "cname": "zstd",
#>         "clevel": 1,
#>         "shuffle": "shuffle",
#>         "typesize": 2,
#>         "blocksize": 0
#>       }
#>     }
#>   }
#> }
```

Ok, that is a lot of things all at once. Let’s walk through this
line-by-line

    VALID

On the top line we see that the document shown is a valid Zarr array
metadata document. You may also get `INCOMPLETE` if some configuration
part is not yet fully defined.

    "zarr_format": 3

This package is for Zarr version 3 and the `array_builder` will only
create metadata documents for version 3. You may persist your data in a
Zarr version 2 store but within this package metadata is always shown in
version 3 format.

    "node_type": "array"

The metadata document is for a Zarr array. The only other option is
`"group"`.

    "shape": [240, 310, 5]

The shape specified in the call to
[`define_array()`](https://r-cf.github.io/zarr/reference/define_array.md).
A shape can have any number of dimensions. The dimensions are specified
in the regular R order.

    "data_type": "int16"

Zarr supports a large number of data types while R only has a few. Data
types are automatically translated between the two environments. The
data type that you specify for the Zarr array is what will be used for
the storage of the data in Zarr; in R, this data type would come out as
an “integer”.

    "fill_value": -32767

Every Zarr array has a `fill_value` for parts of the array that have not
yet been written or where there is no data. The equivalent in R is `NA`.
Every data type has a default `fill_value` but you can also set your
own. In R, you will rarely see the `fill_value` as the data is
automatically transformed from `NA` in R to `fill_value` in Zarr and
*vice-versa*.

    "chunk_grid": {
        "name": "regular",
        "configuration": {
          "chunk_shape": [100, 100, 5]
        }
      }

A Zarr array is stored in “chunked” format, where the array is cut up
into chunks along each dimension. The default setting is to have chunks
with a length of 100 along each dimension (or smaller if the Zarr array
is smaller, as is the case here). This results in chunks with a maximum
size of 8MB for numeric data, 4MB for integer data and 1MB for logical
data, before compression, for a 3D Zarr array with shape
`[100, 100, 100]`. You may set this to a set of values that better
aligns with your array size and your retrieval pattern.

    "codecs"

The codecs are a list of operations that are executed when writing a
Zarr array to a Zarr store (“encoding”) and in reverse order when
reading a Zarr array from a Zarr store into R (“decoding”). This is a
big and complicated one so we’ll look at the individual codecs.

###### “transpose”

The first, optional, processing step is the “transpose” codec. This is
included by default with the indices of the array dimensions in reverse
order. Zarr comes out of the C/Python environment and matrices and
arrays are stored in row-major order. R, on the other hand, used
column-major order. To ensure portability while reducing processing
overhead this codec is included: if it is encountered with the dimension
indices in reverse order, it is a no-op in R. If you want maximum
portability of your Zarr store, including for use in C or Python with
Zarr readers that do not support the transpose codec then you can delete
this codec from the list. Do note, however, that this will increase
processing time when writing and reading Zarr arrays in R.

###### “bytes”

The “bytes” codec is (effectively) mandatory. It takes an R object and
turns it into a byte stream with multi-byte data processed according to
a given byte ordering (or endianness). You very rarely, if ever, have to
worry about this codec.

###### “blosc”

Most Zarr arrays are compressed when stored as that reduces required
file storage and network transmission time. The default compression used
in this package is “blosc”, which includes a number of compression
algorithms, here using “zstd”. The “level” argument can be set from 0
(no compression) to 9 (maximum compression), with higher values leading
to smaller chunk sizes but longer processing. The other arguments are
selected automatically and are best left to their default values. There
are several more compression libraries to choose from.

### Modifying the array definition

The `arr_def` variable is an instance of the `array_builder` class.
Using that class you can easily add of modify parts of the array
definition. As an example, you can set the “chunking” of the array to
different dimension, such as a “clean” portion of each dimension to
avoid having unused parts in the outer-most chunks:

``` r
arr_def$chunk_shape <- c(120, 31, 5)
```

Adding and deleting a codec is a bit more complicated because when
adding you have to specify the name of the codec but also provide a list
with the configuration parameters, and figure out where in the list of
codecs the new codec should be inserted; when deleting the remaining
codecs have to form a valid process. You should consult the online
documentation for the codec to find the right parameters. Once you have
those parameters organized in a list, adding a codec is easy. As an
example, let’s remove the `blosc` codec and insert the `gzip` codec
instead.

``` r
arr_def$remove_codec(codec = "blosc")
arr_def$add_codec(codec = "gzip", configuration = list(level = 5))
#> Loading required namespace: zlib
arr_def
#> <Zarr array metadata> VALID 
#> {
#>   "zarr_format": 3,
#>   "node_type": "array",
#>   "shape": [240, 310, 5],
#>   "data_type": "int16",
#>   "fill_value": -32767,
#>   "chunk_grid": {
#>     "name": "regular",
#>     "configuration": {
#>       "chunk_shape": [120, 31, 5]
#>     }
#>   },
#>   "codecs": {
#>     "transpose": {
#>       "name": "transpose",
#>       "configuration": {
#>         "order": [2, 1, 0]
#>       }
#>     },
#>     "bytes": {
#>       "name": "bytes",
#>       "configuration": {
#>         "endian": "little"
#>       }
#>     },
#>     "gzip": {
#>       "name": "gzip",
#>       "configuration": {
#>         "level": 5
#>       }
#>     }
#>   }
#> }
```

### Creating a Zarr array

Once you are happy with the `arr_def` settings you can create as many
Zarr arrays with it as you need.

``` r
# Create a Zarr object in memory
z <- create_zarr()

# Create a first array in the root group
z$add_array("/", "first_array", arr_def)
#> <Zarr array> first_array 
#> Path      : /first_array 
#> Data type : int16 
#> Shape     : 240 310 5 
#> Chunking  : 120 31 5

# Re-use the array definition
z$add_array("/", "another_array", arr_def)
#> <Zarr array> another_array 
#> Path      : /another_array 
#> Data type : int16 
#> Shape     : 240 310 5 
#> Chunking  : 120 31 5

z$hierarchy()
#> <Zarr hierarchy> 
#> ☰ / (root group)
#> ├ ⌗ first_array
#> └ ⌗ another_array
```

## Reading and writing Zarr arrays

You can access the data in a Zarr object through its arrays. If you do
not specify a name when using function
[`as_zarr()`](https://r-cf.github.io/zarr/reference/as_zarr.md) the Zarr
object can only hold a single array, which is located at the root `"/"`
of the Zarr object. If you do specify a name, then the array is located
at the root of the Zarr store or in a group below that.

``` r
x <- array(1:400, c(5, 20, 4))

fn <- tempfile(fileext = ".zarr")
z <- as_zarr(x, location = fn)

# Get the array using list-like access on the Zarr object
arr <- z[["/"]]
arr
#> <Zarr array>  
#> Path      : / 
#> Data type : int32 
#> Shape     : 5 20 4 
#> Chunking  : 5 20 4

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

# If you want to keep the degenerate first dimension, you have to explicitly 
# indicate that, just like with R arrays.
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

You can also write to a Zarr array directly, for instance to write
smaller subsets of the Zarr array. The process is a bit more
complicated, however (due to a quirk in R):

``` r
arr$write(NA_integer_, selection = list(1:5, 6, 1))
arr$write(-99L, selection = list(2:3, 5:7, 1))
arr[, 1:10, 1]
#>      [,1] [,2] [,3] [,4] [,5] [,6] [,7] [,8] [,9] [,10]
#> [1,]    1    6   11   16   21   NA   31   36   41    46
#> [2,]    2    7   12   17  -99  -99  -99   37   42    47
#> [3,]    3    8   13   18  -99  -99  -99   38   43    48
#> [4,]    4    9   14   19   24   NA   34   39   44    49
#> [5,]    5   10   15   20   25   NA   35   40   45    50
```

A few things of interest here:

1.  The `zarr` package uses the `R6` framework. That means that you
    access fields of the objects just like you would with list elements.
    The Zarr array has multiple properties that you can access using
    this syntax, here retrieving the shape of the Zarr array as an
    integer vector with `d <- arr$shape`.
2.  The data in the Zarr array is of type “int32”, the standard R
    integer. When writing data you should make sure that the object to
    be written is of the correct type, so using `-99L` and `NA_integer_`
    here. Numeric data is stored by default as “float64”, logical data
    as “int8”.
3.  The data is recycled (from a single value to 6 elements in the Zarr
    array) using normal R rules. Do note, however, that only single
    values are recycled and the broadcasting is per dimension of the
    Zarr array.
