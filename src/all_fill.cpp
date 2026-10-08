#include <Rcpp.h>
#include <cstring>
#include <cstdint>

// Does every element of `x` equal the scalar `fill`? Exits at the first
// element that differs. Doubles and integer64 are compared by bit pattern,
// except for a NaN fill of a double array, which matches any NaN.
// [[Rcpp::export]]
bool all_fill_impl(SEXP x, SEXP fill) {
  R_xlen_t n = XLENGTH(x);
  switch (TYPEOF(x)) {
  case REALSXP: {
    const double *p = REAL(x);
    double f = Rf_asReal(fill);
    if (TYPEOF(fill) == REALSXP) f = REAL(fill)[0];   // keep integer64 bits intact
    if (ISNAN(f) && !Rf_inherits(fill, "integer64")) {
      for (R_xlen_t i = 0; i < n; ++i) if (!ISNAN(p[i])) return false;
    } else {
      uint64_t fb, b;
      std::memcpy(&fb, &f, sizeof fb);
      for (R_xlen_t i = 0; i < n; ++i) {
        std::memcpy(&b, p + i, sizeof b);
        if (b != fb) return false;
      }
    }
    return true;
  }
  case INTSXP: case LGLSXP: {
    const int *p = TYPEOF(x) == LGLSXP ? LOGICAL(x) : INTEGER(x);
    int f = TYPEOF(x) == LGLSXP ? Rf_asLogical(fill) : Rf_asInteger(fill);
    for (R_xlen_t i = 0; i < n; ++i) if (p[i] != f) return false;
    return true;
  }
  case STRSXP: {
    SEXP f = Rf_asChar(fill);
    for (R_xlen_t i = 0; i < n; ++i) {
      SEXP s = STRING_ELT(x, i);
      if (f == NA_STRING ? s != NA_STRING
                         : (s == NA_STRING || std::strcmp(CHAR(s), CHAR(f)) != 0)) return false;
    }
    return true;
  }
  default:
    Rcpp::stop("Unsupported type for fill value test");
  }
}
