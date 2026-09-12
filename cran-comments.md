## R CMD check results

0 errors | 0 warnings | 1 note

* checking for portable file names ... NOTE: two recorded HTTP fixture
  files under `tests/testthat/` (httptest2 mocks) have paths that exceed
  the 100-byte tarball component limit. These are generated mock
  directory names from the httptest2 recording convention and do not
  affect package functionality.

## Notes for CRAN

This release migrates the package to AirNow's replacement web services.
AirNow retires the services used by the previous version on 2026-09-30,
after which two of its exported functions stop working. Those functions
are kept as deprecated wrappers around the new ones.

Tests use recorded HTTP fixtures (httptest2) and make no network requests.
