#include <Rcpp.h>
using namespace Rcpp;

//' Fill regions of an output array from a list of inner chunk arrays
//'
//' This function fills `output` in place. For each inner chunk, it copies
//' elements from the decoded chunk into the correct position in the output
//' array. All index arithmetic is done in C++ to avoid R-level copying and
//' garbage collection pressure.
//'
//' @param output A numeric/integer/raw vector with dim attribute set — the
//'   output array to fill. Modified in place via SEXP reference.
//' @param chunks List of decoded inner chunk arrays (already in R order).
//' @param out_offsets List of integer vectors, one per chunk, giving the
//'   0-based offset of that chunk's contribution within `output`.
//' @param ic_offsets List of integer vectors, one per chunk, giving the
//'   0-based offset within the inner chunk to start copying from.
//' @param copy_lengths Integer matrix \code{[nd x n_chunks]} of element counts
//'   to copy along each dimension.
//' @param out_dims Integer vector of output array dimensions.
//' @param ic_dims Integer vector of inner chunk dimensions.
//' @return NULL invisibly; `output` is modified in place.
//' @keywords internal
// [[Rcpp::export]]
void fill_array_impl(SEXP output,
                     List chunks,
                     List out_offsets,
                     List ic_offsets,
                     IntegerMatrix copy_lengths,
                     IntegerVector out_dims,
                     IntegerVector ic_dims) {

  int n_chunks = chunks.size();
  int nd       = out_dims.size();

  // Pre-compute output strides (column-major, R order)
  // stride[0] = 1, stride[1] = out_dims[0], stride[2] = out_dims[0]*out_dims[1], ...
  std::vector<int> out_strides(nd);
  std::vector<int> ic_strides(nd);
  out_strides[0] = 1;
  ic_strides[0]  = 1;
  for (int d = 1; d < nd; d++) {
    out_strides[d] = out_strides[d - 1] * out_dims[d - 1];
    ic_strides[d]  = ic_strides[d - 1] * ic_dims[d - 1];
  }

  for (int ci = 0; ci < n_chunks; ci++) {
    SEXP chunk          = chunks[ci];
    IntegerVector o_off = out_offsets[ci];  // 0-based offset in output
    IntegerVector c_off = ic_offsets[ci];   // 0-based offset in inner chunk

    // Number of elements to copy along each dimension for this chunk
    // copy_lengths is [nd x n_chunks], column-major
    std::vector<int> clen(nd);
    for (int d = 0; d < nd; d++)
      clen[d] = copy_lengths(d, ci);

    // Total elements to copy for this chunk
    int n_elems = 1;
    for (int d = 0; d < nd; d++) n_elems *= clen[d];

    // Iterate over all elements using a flat counter, converting to
    // nd-dimensional indices on the fly (column-major order, matching R)
    for (int elem = 0; elem < n_elems; elem++) {

      // Decompose flat index into per-dimension indices (0-based, within copy region)
      int rem = elem;
      int out_flat = 0;
      int ic_flat  = 0;
      for (int d = 0; d < nd; d++) {
        int coord = rem % clen[d];
        rem      /= clen[d];
        out_flat += (o_off[d] + coord) * out_strides[d];
        ic_flat  += (c_off[d] + coord) * ic_strides[d];
      }

      // Copy one element — type-agnostic via SEXP
      // We handle the three types: REALSXP (numeric), INTSXP (integer),
      // RAWSXP (raw bytes for uint8)
      switch (TYPEOF(output)) {
        case REALSXP:
          REAL(output)[out_flat] = REAL(chunk)[ic_flat];
          break;
        case INTSXP:
          INTEGER(output)[out_flat] = INTEGER(chunk)[ic_flat];
          break;
        case RAWSXP:
          RAW(output)[out_flat] = RAW(chunk)[ic_flat];
          break;
        default:
          Rcpp::stop("Unsupported output type in fill_array_impl");
      }
    }
  }
}
