# Check if the name of a node is valid in Zarr. From the Zarr specification, the following constraints apply to node names:

- must not be the empty string (""), except for the root node

- must not be a string composed only of period characters, e.g. "." or
  ".."

- must not start with the reserved prefix "\_\_".

Only punctuation characters in the set `-, _, .` are allowed. As an
extension to the Zarr specification, characters and numbers can be any
UTF-8 code point. When portability is an issue, restrict characters and
numbers to the set `A-Za-z0-9`.

## Usage

``` r
is_valid_node_name(name)
```

## Arguments

- name:

  Character vector of node names to check.

## Value

Logical vector of the same length as argument `name` with `TRUE` for
each valid node name, `FALSE` otherwise.

## Examples

``` r
is_valid_node_name("simple_name")
#> [1] TRUE
is_valid_node_name("no spaces allowed!")
#> [1] FALSE
```
