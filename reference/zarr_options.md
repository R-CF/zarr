# Zarr package options

Use this function to read or modify package options. On modifying an
option, if the new value is not valid then it is silently discarded and
the original setting remains.

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
#> $group_style
#> [1] "blue" "bold"
#> 
#> $eps
#> [1] 1.490116e-08
#> 
#> $zarr_theme
#> $zarr_theme$h1
#> $zarr_theme$h1$`margin-top`
#> [1] 0
#> 
#> 
#> $zarr_theme$span.group
#> $zarr_theme$span.group$fmt
#> <cli_ansi_style>
#> Example output
#> 
#> 
#> $zarr_theme$span.array
#> $zarr_theme$span.array$fmt
#> <cli_ansi_style>
#> Example output
#> 
#> 
#> $zarr_theme$span.label
#> $zarr_theme$span.label$fmt
#> <cli_ansi_style>
#> Example output
#> 
#> 
#> $zarr_theme$span.text
#> $zarr_theme$span.text$fmt
#> <cli_ansi_style>
#> Example output
#> 
#> 
#> $zarr_theme$span.minor
#> $zarr_theme$span.minor$fmt
#> <cli_ansi_style>
#> Example output
#> 
#> 
#> 
#> $label_style
#> [1] "black" "bold" 
#> 
#> $minor_style
#> [1] "grey"
#> 
#> $min_compress
#> [1] 100
#> 
#> $text_style
#> [1] "blue"
#> 
#> $array_style
#> [1] "green" "bold" 
#> 
#> $parallel_threshold
#> [1] 20
#> 
#> $conventions
#>   name
#> 1  ref
#> 2  uom
#>                                                                                    schema
#> 1 https://raw.githubusercontent.com/R-CF/zarr_convention_ref/refs/tags/v2.0.0/schema.json
#> 2 https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json
#>                                   uuid
#> 1 d89b30cf-ed8c-43d5-9a16-b492f0cd8786
#> 2 3bbe438d-df37-49fe-8e2b-739296d46dfb
#> 
#> $chunk_cache_bytes
#> [1] 67108864
#> 
```
