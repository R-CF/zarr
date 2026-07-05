# Convention "ref"

This class implements the "ref" convention. This convention provides a
standard way of referring to objects from a referring group or array in
a Zarr store. The referenced object may be located in the same Zarr
store or in an external Zarr store. In particular, the following
convention is implemented here:

    {
     "schema_url": "https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/schema.json",
     "spec_url": "https://raw.githubusercontent.com/R-CF/zarr_convention_ref/main/README.md",
     "uuid": "d89b30cf-ed8c-43d5-9a16-b492f0cd8786",
     "name": "ref",
     "description": "Referencing Zarr objects external to the current Zarr object"
    }

## Super class

[`zarr_convention`](https://r-cf.github.io/zarr/reference/zarr_convention.md)
-\> `zarr_convention_ref`

## Methods

### Public methods

- [`zarr_convention_ref$new()`](#method-zarr_convention_ref-initialize)

- [`zarr_convention_ref$set()`](#method-zarr_convention_ref-set)

- [`zarr_convention_ref$clear()`](#method-zarr_convention_ref-clear)

- [`zarr_convention_ref$as_list()`](#method-zarr_convention_ref-as_list)

Inherited methods

- [`zarr_convention$register()`](https://r-cf.github.io/zarr/reference/zarr_convention.html#method-register)

------------------------------------------------------------------------

### `zarr_convention_ref$new()`

Create a new instance of a "ref" convention agent.

#### Usage

    zarr_convention_ref$new()

#### Returns

A new instance of a "ref" convention agent.

------------------------------------------------------------------------

### `zarr_convention_ref$set()`

Set the attributes for this convention for use in a Zarr node.

#### Usage

    zarr_convention_ref$set(node, uri, attribute)

#### Arguments

- `node`:

  Character string. Path to the Zarr node containing the data of
  interest. The path is relative to the referring node when argument
  `uri` is missing, absolute from the root of the Zarr store otherwise.

- `uri`:

  Optional, character string. URI of an external Zarr store. Omit for
  nodes that are in the same local store as the referring node.

- `attribute`:

  Optional, a character string with a JSON pointer to a referenced
  attribute in the metadata of the referenced `node`.

------------------------------------------------------------------------

### `zarr_convention_ref$clear()`

Clear any attributes that may have been set. Only the properties of the
convention itself will remain in place.

#### Usage

    zarr_convention_ref$clear()

------------------------------------------------------------------------

### `zarr_convention_ref$as_list()`

Return the data of this instance for inclusion in the attributes of a
Zarr object.

#### Usage

    zarr_convention_ref$as_list()

#### Returns

A `list` with Zarr attributes for a group or array.
