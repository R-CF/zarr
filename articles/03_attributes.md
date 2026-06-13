# 3. Working with attributes

Zarr groups and arrays can have attributes associated with them.
Attributes are typically character strings describing some notable
feature of a group or array, such as the physical unit of the data in an
array or the intended use of one or more arrays. Attributes may also be
numeric, such as in the case of a range of valid values for an array.
Most (simple) R objects, including hierarchically structured lists, can
be used in attributes but it is not recommended to use large objects.
Matrices and arrays should be avoided where possible because there is no
good way to indicate the storage order of the values. Attributes are
best held small for performance reasons. Attributes are stored in the
same “zarr.json” metadata files as the structural information on groups
and arrays and large attributes will thus slow down the opening and
writing of groups and arrays.

Attributes are also used to set the properties of Zarr stores, groups
and arrays that are formatted according to a certain profile, such as
GeoZarr for geo-spatial data. Such attributes are managed by the profile
code and should not be modified manually unless the profile
documentation allows it. See the Profiles article for more details.

## Quick start

Attribute management is very easy, using methods `set_attribute()`,
`append_array_attribute()` and `delete_attribute()`, available for both
`zarr_group` and `zarr_array` instances.

``` r

library(zarr)

# Create an in-memory Zarr object
z <- create_zarr()

# Set attributes in the root group, a.k.a. global attributes
z[["/"]]$set_attribute("title", "Data set for intelligent analysis of foo.")
z[["/"]]$set_attribute("creator", "ACME Inc.")
z[["/"]]$set_attribute("license", "free (as in free lunch)")
z
#> <Zarr>
#> Version   : 3 
#> Store     : memory store 
#> Arrays    : 0 
#> 
#> Attributes: (*)
#> title  : Data set for intelligent analysis of foo.
#> creator: ACME Inc.
#> license: free (as in free lunch)

# Create an array and attach some attributes
x <- array(runif(20000), c(100, 200))
arr <- as_zarr(x, "bar", z[["/"]])
arr$set_attribute("title", "Bar for foo")
arr$set_attribute("valid_range", c(0, 1))
arr$set_attribute("actual_range", range(x))
arr 
#> <Zarr array> ⌗ bar 
#> Path      : /bar 
#> Data type : float64 
#> Shape     : 100 200 
#> Chunking  : 100 100 
#> 
#> Attributes: (*)
#> title       : Bar for foo
#> valid_range : [0, 1]
#> actual_range: [2.5581568479538e-05, 0.999872711254284]
```

You can programmatically retrieve the full set of attributes with the
`attributes` field of `zarr_group` and `zarr_array`. The attributes are
returned to the caller as a `list`. Individual attributes can be
retrieved with the `attribute()` method.

You can update or overwrite an existing attribute simply by setting the
new value for the attribute. In combination with accessing all
attributes this allows you to update an existing attribute value too.

``` r

arr$set_attribute("title", paste(arr$attributes[["title"]], "and baz too"))
arr
#> <Zarr array> ⌗ bar 
#> Path      : /bar 
#> Data type : float64 
#> Shape     : 100 200 
#> Chunking  : 100 100 
#> 
#> Attributes: (*)
#> title       : Bar for foo and baz too
#> valid_range : [0, 1]
#> actual_range: [2.5581568479538e-05, 0.999872711254284]
```

If you want to delete an attribute, use the `delete_attribute()` method
with the attribute name to delete as argument.

``` r

arr$delete_attribute("valid_range")
arr
#> <Zarr array> ⌗ bar 
#> Path      : /bar 
#> Data type : float64 
#> Shape     : 100 200 
#> Chunking  : 100 100 
#> 
#> Attributes: (*)
#> title       : Bar for foo and baz too
#> actual_range: [2.5581568479538e-05, 0.999872711254284]
```

The `(*)` after the the heading “Attributes:” indicates that there are
unsaved changes to the attributes, meaning that the changes have not
been persisted to a Zarr store. If you wish to persist those changes,
simply call `arr$save()`.

## Compound attributes and attribute arrays

The attributes in Zarr groups and arrays are stored in a JSON file
called `zarr.json` (`.zattrs` in Zarr v.2). Each group or array has one
such file. JSON attributes can be nested and they can contains “arrays”
(a vector of values, in R-speak). These features are also supported by
the `zarr` package.

Inside the JSON file the attributes are stored under the top-level
`"attributes"` element. The JSON file for the Zarr array “bar” resulting
from the above quick start looks like this:

    {
      "zarr_format": 3,
      "node_type": "array",
      "shape": [100, 200],
      "data_type": "float64",
      "fill_value": 9.9692099683868667e+36,
      "chunk_grid": {
        "name": "regular",
        "configuration": {
          "chunk_shape": [100, 100]
        }
      },
      "codecs": [
        {
          "name": "transpose",
          "configuration": {
            "order": [1, 0]
          }
        },
        {
          "name": "bytes",
          "configuration": {
            "endian": "little"
          }
        },
        {
          "name": "blosc",
          "configuration": {
            "clevel": 6,
            "cname": "zstd",
            "shuffle": "bitshuffle",
            "typesize": 8,
            "blocksize": 0
          }
        }
      ],
      "chunk_key_encoding": {
        "name": "default",
        "configuration": {
          "separator": "."
        }
      },
      "attributes": {
        "title": "Bar for foo and baz too",
        "actual_range": [0, 1]
      }
    }

The three attribute manipulation methods of this package only work on
data below the top-level `"attributes"` element. You should never place
any data directly in the root of the JSON document, it may ruin your
data.

### Paths

Referencing nested attributes is done by separating path elements with a
slash `"/"` with the attribute name at the end. The first element is
always relative to the `"attributes"` element in the JSON file and does
not have a preceding slash. As an example:
`"this/is/a/compound/path/my_attribute"`. When you set an attribute with
a path, any elements in the path that do not yet exist are automatically
created.

``` r

z <- create_zarr()

# Set global attributes in the root group
z[["/"]]$set_attribute("simple", "root level attribute")
z[["/"]]$set_attribute("compound/path/my_attribute", "nested attribute")
z[["/"]]$set_attribute("compound/different/branch/goes/deeper/att", "buried attribute")
z[["/"]]
#> <Zarr group> [root] 
#> Path     : / 
#> 
#> Attributes: (*)
#> simple  : root level attribute
#> compound:
#>   path     :
#>     my_attribute: nested attribute
#>   different:
#>     branch:
#>       goes:
#>         deeper:
#>           att: buried attribute
```

When you delete an attribute, you can provide a (partial) path and
everything below that path will be deleted:

``` r

z[["/"]]$delete_attribute("compound/different/branch")
z[["/"]]
#> <Zarr group> [root] 
#> Path     : / 
#> 
#> Attributes: (*)
#> simple  : root level attribute
#> compound:
#>   path     :
#>     my_attribute: nested attribute
#>   different: []
```

Note how the element `"different"` is still there, but it is an empty
list.

### JSON arrays

JSON arrays do not use names, they use indexes. You can create a JSON
array with the `append_array_attribute()`:

``` r

z[["/"]]$append_array_attribute("compound/different/an_array", "first array element")
z[["/"]]
#> <Zarr group> [root] 
#> Path     : / 
#> 
#> Attributes: (*)
#> simple  : root level attribute
#> compound:
#>   path     :
#>     my_attribute: nested attribute
#>   different:
#>     an_array: [first array element]
```

You do not actually add an object that is an array (although you could
pass a vector), but rather the object that you provide is stored in a
JSON array. You can add further elements to the same array, possibly
selecting a specific location to insert the element:

``` r

# Add an element at the end of the array - default behaviour
z[["/"]]$append_array_attribute("compound/different/an_array", "second array element")

# Insert the element somewhere in the existing array
z[["/"]]$append_array_attribute("compound/different/an_array", "very first array element", after = 0)

z[["/"]]
#> <Zarr group> [root] 
#> Path     : / 
#> 
#> Attributes: (*)
#> simple  : root level attribute
#> compound:
#>   path     :
#>     my_attribute: nested attribute
#>   different:
#>     an_array: [very first array element, first array element, second array element]
```

Array elements can be of different type (unlike in R):

``` r

z[["/"]]$append_array_attribute("compound/different/an_array", 4L)

# Elements may be (compound) lists too
z[["/"]]$append_array_attribute("compound/different/an_array", list(string = "an_item", array_in_array = 1:10))

z[["/"]]
#> <Zarr group> [root] 
#> Path     : / 
#> 
#> Attributes: (*)
#> simple  : root level attribute
#> compound:
#>   path     :
#>     my_attribute: nested attribute
#>   different:
#>     an_array:
#>       [1]
#>         very first array element
#>       [2]
#>         first array element
#>       [3]
#>         second array element
#>       [4]
#>         4
#>       [5]
#>         string        : an_item
#>         array_in_array: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
```

The distinction between a JSON object an an array is that the former is
a named list in R and the latter an unnamed list.

### Building nested attribute stores

Using paths and JSON arrays you an build attribute stores to any desired
level of nesting. As shown in the last example in the previous section,
you may even insert whole list structures in a single element, which
then automatically expands to a hierarchy of attributes. In fact, the
`zarr` package manages the Zarr group and array attributes in exactly
that way (as does the `jsonlite` package which is used for serializing
the full metadata object).

The hierarchy is easily traversed using the paths to any attribute or
group of attributes, including over JSON arrays:

``` r

z[["/"]]$attribute("compound/different/an_array/5/string")
#> [1] "an_item"
z[["/"]]$attribute("compound/different/an_array/5/array_in_array/3")
#> [1] 3

# Get a branch of attributes
z[["/"]]$attribute("compound/different/an_array")
#> [[1]]
#> [1] "very first array element"
#> 
#> [[2]]
#> [1] "first array element"
#> 
#> [[3]]
#> [1] "second array element"
#> 
#> [[4]]
#> [1] 4
#> 
#> [[5]]
#> [[5]]$string
#> [1] "an_item"
#> 
#> [[5]]$array_in_array
#>  [1]  1  2  3  4  5  6  7  8  9 10
```

A few things to keep in mind:

- After changing any attributes for a local file system Zarr store, call
  [`save()`](https://rdrr.io/r/base/save.html) to persist the edits to
  file. This must be done for every Zarr group and array where edits
  were made.
- When storing references to JSON array elements from elsewhere in the
  attributes, you should use 0-based indexing.
