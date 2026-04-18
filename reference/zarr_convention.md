# Zarr convention

This class implements a basic Zarr convention. A convention is a set of
attributes specific to a certain domain of application. These attributes
are included in Zarr group and array attributes and are interpreted by
application code. Conventions may be grouped in domains and combined
with other conventions.

Application-specific conventions need to inherit from this base class
and redefine relevant methods. Descendant conventions may have
additional methods specific to the domain of the data.

It is not useful to directly instantiate this class, use a descendant
convention instead. It is recommended that descendant classes use the
"zarr_conv\_\*\*\*\*" naming pattern and that they are included in a R
package with similar conventions and/or domain(s).

## Active bindings

- `name`:

  (read-only) The name of the convention, possibly with a trailing
  semi-colon ":".

- `schema`:

  (read-only) The URL to the schema of the convention.

- `uuid`:

  (read-only) The UUID of the convention, in string format.

- `spec`:

  The URL to the specification of the convention.

- `description`:

  A short description of the convention.

## Methods

### Public methods

- [`zarr_convention$new()`](#method-zarr_convention-new)

- [`zarr_convention$register()`](#method-zarr_convention-register)

- [`zarr_convention$write()`](#method-zarr_convention-write)

------------------------------------------------------------------------

### Method `new()`

Create a new instance of a Zarr convention agent. This is a "virtual"
ancestor class that should not be instantiated directly - instead use
one of the descendant classes.

#### Usage

    zarr_convention$new(name, schema, uuid)

#### Arguments

- `name`:

  String value with the name of the convention.

- `schema`:

  String value with the URL to the schema of the convention.

- `uuid`:

  String value with the UUID of the convention.

#### Returns

A new instance of a Zarr convention agent.

------------------------------------------------------------------------

### Method `register()`

Register the use of a convention in the attributes of a Zarr object.

#### Usage

    zarr_convention$register(attributes, brief = FALSE)

#### Arguments

- `attributes`:

  A `list` with Zarr attributes for a group or array.

- `brief`:

  Logical flag to indicate if the registration should only include the
  name and the schema URL or all details (default).

#### Returns

The updated attributes.

------------------------------------------------------------------------

### Method [`write()`](https://rdrr.io/r/base/write.html)

Write the data of a convention instance in the attributes of a Zarr
object. This method does not do any actual writing. Descendant classes
should implement their specific solutions.

#### Usage

    zarr_convention$write(attributes)

#### Arguments

- `attributes`:

  A `list` with Zarr attributes for a group or array. The properties
  will be written at the root level of `attributes`.

#### Returns

The updated attributes.
