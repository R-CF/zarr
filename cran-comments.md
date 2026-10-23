## Release details
This is a major release of the package with significant new functionality.

### API BREAKING CHANGES
The revdepcheck, details below, shows one failing dependency. This is expected 
and managed: the geozarr package has incorporated the API changes and builds 
cleanly against the zarr package as submitted. The geozarr package will be 
submitted to CRAN as soon as the new release of this package is available on
CRAN.

## R CMD check results

0 errors | 0 warnings | 0 notes

## revdepcheck results

We checked 1 reverse dependencies, comparing R CMD check results across CRAN and
dev versions of this package.

 * We saw 1 new problems
 * We failed to check 0 packages

Issues with CRAN packages are summarised below.

### New problems
(This reports the first line of each new failure)

* geozarr
  checking examples ... ERROR
  checking tests ...
