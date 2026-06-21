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

[`zarr_convention`](https://r-cf.github.io/zarr/reference/zarr_convention.md)
-\> `zarr_convention_uom`

## Methods

### Public methods

- [`zarr_convention_uom$new()`](#method-zarr_convention_uom-initialize)

- [`zarr_convention_uom$set()`](#method-zarr_convention_uom-set)

- [`zarr_convention_uom$clear()`](#method-zarr_convention_uom-clear)

- [`zarr_convention_uom$as_list()`](#method-zarr_convention_uom-as_list)

Inherited methods

- [`zarr_convention$register()`](https://r-cf.github.io/zarr/reference/zarr_convention.html#method-register)

------------------------------------------------------------------------

### `zarr_convention_uom$new()`

Create a new instance of a "uom" convention agent.

#### Usage

    zarr_convention_uom$new()

#### Returns

A new instance of a "uom" convention agent.

------------------------------------------------------------------------

### `zarr_convention_uom$set()`

Set the attributes for this convention for use in a Zarr node.

#### Usage

    zarr_convention_uom$set(unit, version, description)

#### Arguments

- `unit`:

  Character string. The "unit" attribute under "ucum", giving the
  unit-of-measure in UCUM notation.

- `version`:

  Optional, character string. The "version" attribute under "ucum",
  indicating the UCUM version that is being used.

- `description`:

  Optional, a character string with the "description" attribute, giving
  a free-text description of the unit-of-measure.

------------------------------------------------------------------------

### `zarr_convention_uom$clear()`

Reset any attributes that may have been set to their default values.
Only the properties of the convention itself will remain in place.

#### Usage

    zarr_convention_uom$clear()

------------------------------------------------------------------------

### `zarr_convention_uom$as_list()`

Return the data of this instance for inclusion in the attributes of a
Zarr object.

#### Usage

    zarr_convention_uom$as_list()

#### Returns

A `list` with Zarr attributes for a group or array.
