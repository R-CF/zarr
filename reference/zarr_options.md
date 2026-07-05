# Zarr package options

Use this function to read or modify package options.

## Usage

``` r
zarr_options(key, value)
```

## Arguments

- key:

  Character. A key whose value to retrieve or modify. If missing, all
  options are returned.

- value:

  Optional. The new value for the option.

## Value

Nothing if argument `value` is provided. The value of argument `key` if
it is provided, or a `list` with all options otherwise.

## Examples

``` r
zarr_options()
#> $chunk_length
#> [1] 100
#> 
#> $eps
#> [1] 1.490116e-08
#> 
#> $min_compress
#> [1] 100
#> 
#> $parallel_threshold
#> [1] 20
#> 
#> $conventions
#>   name
#> 1  ref
#> 2  uom
#>                                                                                    schema
#> 1             https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/schema.json
#> 2 https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json
#>                                   uuid
#> 1 d89b30cf-ed8c-43d5-9a16-b492f0cd8786
#> 2 3bbe438d-df37-49fe-8e2b-739296d46dfb
#> 
```
