# Zarr domain

This class implements a basic domain object for Zarr stores. Domains are
specific encodings for a certain domain of application. These encodings
are included in the attributes of the Zarr groups and arrays and need
custom code (usually in the form of another package) to interpret the
attributes and properly process array data. Domains can be fully
application-specific or they can implement one or more published Zarr
conventions.

Domains have to be registered with this package to become available to
the processing pipeline. Domain code is then called automatically when a
Zarr store is opened for all groups and arrays in the store.

New domains need to inherit from this base class and implement all of
the relevant methods. New domains may have additional methods specific
to the domain of the data. It is generally not useful to directly
instantiate this class: for a Zarr store without a registered domain an
instance of this class is initialized automatically.

## Active bindings

- `name`:

  (read-only) The name of the domain.

- `can_read`:

  (read-only) Flag to indicate if this domain can read a Zarr store
  using this domain. Should always be `TRUE`.

- `can_write`:

  (read-only) Flag to indicate if this domain can write a Zarr store
  using this domain. `TRUE` for a generic Zarr store; other domains may
  report \`FALSE.

## Methods

### Public methods

- [`zarr_domain$new()`](#method-zarr_domain-new)

- [`zarr_domain$build()`](#method-zarr_domain-build)

------------------------------------------------------------------------

### Method `new()`

Create a new instance of a Zarr domain. This method should not be called
directly (as in `zarr_domain$new()`); instead, descendant classes will
call this method in their initialization code.

#### Usage

    zarr_domain$new(name)

#### Arguments

- `name`:

  Character string giving the name of the domain. This may be any
  sensible string value. The name of the domain must be unique in the
  session or an error will be thrown upon registering the domain.

#### Returns

A new instance of a domain class.

------------------------------------------------------------------------

### Method `build()`

This method will be called when the domain is requested to asses the
Zarr node for domain properties. This method must be implemented by
descendant classes and return an appropriate node if it will manage the
node. The code should be agile and return swiftly so any non-trivial
operations should be left to a later moment, for instance when the node
is accessed by the application or end-user.

#### Usage

    zarr_domain$build(name, metadata, parent, store)

#### Arguments

- `name`:

  The name of the node.

- `metadata`:

  List with the metadata of the node.

- `parent`:

  The parent node of this new node. May be `NULL` for a root node.

- `store`:

  The store to persist data in.

#### Returns

A `zarr_node` descendant, typically an instance of a domain-specific
descendant class of `zarr_array` or `zarr_group`. If the domain does not
want to manage the node, return `FALSE`.
