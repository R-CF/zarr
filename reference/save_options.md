# Save the options to a file in the user config directory

This functions saves the options of the `zarr` package in a RDS file in
the config directory of the user. This will persist modified options
over multiple sessions. The file is automatically read when a new
session starts. Note that saving the options is only necessary when any
options have been modified and these changes need to apply to future
sessions as well.

## Usage

``` r
save_options()
```

## Value

Nothing.

## Examples

``` r
save_options()
```
