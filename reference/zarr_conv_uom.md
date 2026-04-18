# Convention "uom"

This class implements the "uom" convention. This convention provides a
standard way of describing the unit-of-measure of Zarr array data or an
attribute. In particular, the following convention is implemented here:

    {
      "schema_url": "https://raw.githubusercontent.com/clbarnes/zarr-convention-uom/refs/tags/v1/schema.json",
      "spec_url": "https://github.com/clbarnes/zarr-convention-uom/blob/v1/README.md",
      "uuid": "3bbe438d-df37-49fe-8e2b-739296d46dfb",
      "name": "uom",
      "description": "Units of measurement for Zarr arrays"
    }

## Super class

[`zarr::zarr_convention`](https://r-cf.github.io/zarr/reference/zarr_convention.md)
-\> `zarr_conv_uom`

## Active bindings

- `version`:

  The "version" attribute under "ucum", a character string indicating
  the UCUM vesion that is being used.

- `unit`:

  The "unit" attribute under "ucum", a character string giving the
  unit-of-measure in UCUM notation.

- `description`:

  The "description" attribute, a character string giving a free-text
  description of the unit-of-measure.

## Methods

### Public methods

- [`zarr_conv_uom$new()`](#method-zarr_conv_uom-new)

- [`zarr_conv_uom$write()`](#method-zarr_conv_uom-write)

Inherited methods

- [`zarr::zarr_convention$register()`](https://r-cf.github.io/zarr/reference/zarr_convention.html#method-register)

------------------------------------------------------------------------

### Method `new()`

Create a new instance of a "uom" convention agent.

#### Usage

    zarr_conv_uom$new()

#### Returns

A new instance of a "uom" convention agent.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write the data of this instance in the attributes of a Zarr object.

#### Usage

    zarr_conv_uom$write(attributes)

#### Arguments

- `attributes`:

  A `list` with Zarr attributes for a group or array. The properties
  will be written to `attributes`.

#### Returns

The updated attributes.
