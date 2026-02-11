# Define the properties of a new Zarr array.

With this function you can create a skeleton Zarr array from some key
properties and a number of derived properties. Compression of the data
is set to a default algorithm and level. This function returns an
[array_builder](https://r-cf.github.io/zarr/reference/array_builder.md)
instance with which you can create directly the Zarr array, or set
further properties before creating the array.

## Usage

``` r
define_array(data_type, shape)
```

## Arguments

- data_type:

  The data type of the Zarr array.

- shape:

  An integer vector giving the length along each dimension of the array.

## Value

A `array_builder` instance with which a Zarr array can be created.

## Examples

``` r
x <- array(1:120, c(3, 8, 5))
def <- define_array("int32", dim(x))
def$chunk_shape <- c(4, 4, 4)
z <- create_zarr() # Creates a Zarr object in memory
arr <- z$add_array("/", "my_array", def)
arr$write(x)
arr
#> <Zarr array> my_array 
#> Path      : /my_array 
#> Data type : int32 
#> Shape     : 3 8 5 
#> Chunking  : 4 4 4 
```
