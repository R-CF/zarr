# 3. Working with attributes

Zarr groups and arrays can have attributes associated with them.
Attributes are typically character strings describing some notable
feature of a group or array, such as the physical unit of the data in an
array or the intended use of one or more arrays. Attributes may also be
numeric, such as in the case of a range of valid values for an array.
Most (simple) R objects can be used in attributes but it is not
recommended to use compound
(e.g. [`list()`](https://rdrr.io/r/base/list.html)) or large objects.
Matrices and arrays should be avoided where possible because there is no
good way to indicate the storage order of the values. Attributes are
best held small for performance reasons. Attributes are stored in the
same “zarr.json” metadata files as the structural information on groups
and arrays and large attributes will thus slow down the opening and
writing of groups and arrays.

Attribute management is very easy, using two methods `set_attribute()`
and `delete_attributes()`, available for both `zarr_group` and
`zarr_array` instances.

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
#> Attributes: (*)
#>  name    value                                    
#>  title   Data set for intelligent analysis of foo.
#>  creator ACME Inc.                                
#>  license free (as in free lunch)

# Create an array and attach some attributes
x <- array(runif(20000), c(100, 200))
arr <- as_zarr(x, "bar", z[["/"]])
arr$set_attribute("title", "Bar for foo")
arr$set_attribute("valid_range", c(0, 1))
arr$set_attribute("actual_range", range(x))
arr 
#> <Zarr array> bar 
#> Path      : /bar 
#> Data type : float64 
#> Shape     : 100 200 
#> Chunking  : 100 100 
#> Attributes: (*)
#>  name         value                                 
#>  title        Bar for foo                           
#>  valid_range  0, 1                                  
#>  actual_range 2.5581568479538e-05, 0.999872711254284
```

You can programmatically retrieve the full set of attributes with the
`attributes` field of `zarr_group` and `zarr_array`. The attributes are
returned to the caller as a `list`.

You can update or overwrite an existing attribute simply by setting the
new value for the attribute. In combination with accessing all
attributes this allows you to update an existing attribute value too.

``` r
arr$set_attribute("title", paste(arr$attributes[["title"]], "and baz too"))
arr
#> <Zarr array> bar 
#> Path      : /bar 
#> Data type : float64 
#> Shape     : 100 200 
#> Chunking  : 100 100 
#> Attributes: (*)
#>  name         value                                 
#>  title        Bar for foo and baz too               
#>  valid_range  0, 1                                  
#>  actual_range 2.5581568479538e-05, 0.999872711254284
```

If you want to delete one or more attributes, use the
`delete_attributes()` method which takes a vector of attribute names to
delete.

``` r
arr$delete_attributes(c("valid_range", "actual_range"))
arr
#> <Zarr array> bar 
#> Path      : /bar 
#> Data type : float64 
#> Shape     : 100 200 
#> Chunking  : 100 100 
#> Attributes: (*)
#>  name  value                  
#>  title Bar for foo and baz too
```

The `(*)` after the the heading “Attributes:” indicates that there are
unsaved changes to the attributes, meaning that the changes have not
been persisted to a Zarr store. If you wish to persist those changes,
simply call `arr$save()`.
