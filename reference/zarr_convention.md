# Zarr convention

This class implements a basic Zarr convention attribute factory. A
convention is a set of attributes specific to a certain domain of
application. These attributes are included in Zarr group and array
attributes and are interpreted by application code. Conventions may be
grouped in domains and combined with other conventions.

Application-specific conventions need to inherit from this base class
and redefine relevant methods. Descendant conventions may have
additional methods specific to the domain of the data. Descendants of
this class take the elements that define it and then return them
formatted for inclusion in the attributes of a Zarr node.

It is not useful to directly instantiate this class, use a descendant
convention instead. It is recommended that descendant classes use the
"zarr_convention\_\*" naming pattern and that they are included in a R
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

- [`zarr_convention$new()`](#method-zarr_convention-initialize)

- [`zarr_convention$register()`](#method-zarr_convention-register)

- [`zarr_convention$set()`](#method-zarr_convention-set)

- [`zarr_convention$as_list()`](#method-zarr_convention-as_list)

- [`zarr_convention$clear()`](#method-zarr_convention-clear)

------------------------------------------------------------------------

### `zarr_convention$new()`

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

### `zarr_convention$register()`

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

### `zarr_convention$set()`

Set the attributes for this convention for use in a Zarr node. This is a
stub that descendant classes can implement, using a specific set of
arguments. More complex conventions can use other arrangements to set
the more complex attributes.

#### Usage

    zarr_convention$set()

------------------------------------------------------------------------

### `zarr_convention$as_list()`

Format the elements of a convention instance in a list suitable for the
attributes of a Zarr object. Descendant classes should implement their
specific solutions.

#### Usage

    zarr_convention$as_list()

#### Returns

The convention attributes in a list.

------------------------------------------------------------------------

### `zarr_convention$clear()`

Clear any attributes that may have been set. Only the properties of the
convention itself will remain in place.

#### Usage

    zarr_convention$clear()
