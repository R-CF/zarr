# Fill regions of an output array from a list of inner chunk arrays

This function fills `output` in place. For each inner chunk, it copies
elements from the decoded chunk into the correct position in the output
array. All index arithmetic is done in C++ to avoid R-level copying and
garbage collection pressure.

## Usage

``` r
fill_array_impl(
  output,
  chunks,
  out_offsets,
  ic_offsets,
  copy_lengths,
  out_dims,
  ic_dims
)
```

## Arguments

- output:

  A numeric/integer/raw vector with dim attribute set — the output array
  to fill. Modified in place via SEXP reference.

- chunks:

  List of decoded inner chunk arrays (already in R order).

- out_offsets:

  List of integer vectors, one per chunk, giving the 0-based offset of
  that chunk's contribution within `output`.

- ic_offsets:

  List of integer vectors, one per chunk, giving the 0-based offset
  within the inner chunk to start copying from.

- copy_lengths:

  Integer matrix `[nd x n_chunks]` of element counts to copy along each
  dimension.

- out_dims:

  Integer vector of output array dimensions.

- ic_dims:

  Integer vector of inner chunk dimensions.

## Value

NULL invisibly; `output` is modified in place.
