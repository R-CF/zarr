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

[`zarr::zarr_convention`](https://r-cf.github.io/zarr/reference/zarr_convention.md)
-\> `zarr_conv_ref`

## Active bindings

- `uri`:

  The "uri" field, a character string of an external Zarr store. The URI
  must follow RFC 3986 and preferably points to a locatable resource
  like a file on a file system or a store on a web site that is
  accessible to the same process that opened up the Zarr store having
  this reference.

- `node`:

  The "node" field, a character string giving the path to a group or
  array in the current Zarr store or in the store pointed at by the
  "uri" field.

- `attribute`:

  The "attribute" field, a character string with a JSON pointer to a
  referenced attribute in the metadata of the referenced `node`.

## Methods

### Public methods

- [`zarr_conv_ref$new()`](#method-zarr_conv_ref-new)

- [`zarr_conv_ref$write()`](#method-zarr_conv_ref-write)

- [`zarr_conv_ref$parse_json_pointer()`](#method-zarr_conv_ref-parse_json_pointer)

Inherited methods

- [`zarr::zarr_convention$register()`](https://r-cf.github.io/zarr/reference/zarr_convention.html#method-register)

------------------------------------------------------------------------

### Method `new()`

Create a new instance of a "ref" convention agent.

#### Usage

    zarr_conv_ref$new()

#### Returns

A new instance of a "ref" convention agent.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write the data of this instance in the attributes of a Zarr object.

#### Usage

    zarr_conv_ref$write(attributes)

#### Arguments

- `attributes`:

  A `list` with Zarr attributes for a group or array. The properties
  will be written to `attributes`.

#### Returns

The updated attributes.

------------------------------------------------------------------------

### Method `parse_json_pointer()`

Validate and parse a JSON Pointer (RFC 6901) into its reference tokens.

#### Usage

    zarr_conv_ref$parse_json_pointer(ptr)

#### Arguments

- `ptr`:

  The character string from the "attribute" field to parse.

#### Returns

Character vector of raw tokens, or throws an error.
