# Zarr data types

This class implements a Zarr data type as an extension point. This class
also manages the "fill_value" attribute associated with the data type.

## Super class

[`zarr::zarr_extension`](https://r-cf.github.io/zarr/reference/zarr_extension.md)
-\> `zarr_data_type`

## Active bindings

- `data_type`:

  The data type for the Zarr array, a single character string. Setting
  the data type will also set the fill value to its default value.

- `Rtype`:

  (read-only) The R data type corresponding to the Zarr data type.

- `signed`:

  (read-only) Flag that indicates if the Zarr data type is signed or
  not.

- `size`:

  (read-only) The size of the data type, in bytes.

- `fill_value`:

  The fill value for the Zarr array, a single value that agrees with the
  range of the `data_type`.

## Methods

### Public methods

- [`zarr_data_type$new()`](#method-zarr_data_type-new)

- [`zarr_data_type$print()`](#method-zarr_data_type-print)

- [`zarr_data_type$metadata_fragment()`](#method-zarr_data_type-metadata_fragment)

------------------------------------------------------------------------

### Method `new()`

Create a new data type object.

#### Usage

    zarr_data_type$new(data_type, fill_value = NULL)

#### Arguments

- `data_type`:

  The name of the data type, a single character string.

- `fill_value`:

  Optionally, the fill value for the data type.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a summary of the data type to the console.

#### Usage

    zarr_data_type$print()

------------------------------------------------------------------------

### Method `metadata_fragment()`

Return the metadata fragment for this data type and its fill value.

#### Usage

    zarr_data_type$metadata_fragment()

#### Returns

A list with the metadata fragment.
