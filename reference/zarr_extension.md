# Zarr extension support

Many aspects of a Zarr array are implemented as extensions. More
precisely, all core properties of a Zarr array except for its shape are
defined as extension points, down to its data type. This class is the
basic ancestor for extensions. It supports generation of the appropriate
metadata for the extension, as well as processing in more specialized
descendant classes.

Extensions can be nested. For instance, a sharding object contains one
or more codecs, with both the sharding object and the codec being
extension points.

## Active bindings

- `name`:

  The name of the extension. Setting the name may be restricted by
  descendant classes.

## Methods

### Public methods

- [`zarr_extension$new()`](#method-zarr_extension-new)

- [`zarr_extension$metadata_fragment()`](#method-zarr_extension-metadata_fragment)

------------------------------------------------------------------------

### Method `new()`

Create a new extension object.

#### Usage

    zarr_extension$new(name)

#### Arguments

- `name`:

  The name of the extension, a single character string.

#### Returns

An instance of this class.

------------------------------------------------------------------------

### Method `metadata_fragment()`

Return the metadata fragment that describes this extension point object.
This includes the metadata of any nested extension objects.

#### Usage

    zarr_extension$metadata_fragment()

#### Returns

A list with the metadata of this extension point object.
