## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes for CRAN

This release migrates the package to AirNow's replacement web services.
AirNow retires the services used by the previous version on 2026-09-30,
after which two of its exported functions stop working. Those functions
are kept as deprecated wrappers around the new ones.

Tests use recorded HTTP fixtures (httptest2) and make no network requests
on CRAN; one live smoke test is guarded by skip_on_cran().
