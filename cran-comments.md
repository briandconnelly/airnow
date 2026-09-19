## Test environments

* local macOS 26.6 (arm64), R 4.6.1
* macOS builder (mac.R-project.org), macOS 26.6 (arm64), R 4.6.1 Patched
* GitHub Actions: Windows Server 2022, R 4.6.1
* GitHub Actions: Ubuntu 24.04, R 4.6.1
* GitHub Actions: Ubuntu 24.04, R devel (2026-09-18 r90566)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

There are currently no reverse dependencies for this package.

## Notes for CRAN

This release migrates the package to AirNow's replacement web services.
AirNow retires the services used by the previous version on 2026-09-30,
after which two of its exported functions stop working. Those functions
are kept as deprecated wrappers around the new ones. AirNow's announcement
of the change:
https://docs.airnowapi.org/docs/AirNowAPIUpdates2026June.pdf

Tests use recorded HTTP fixtures (httptest2) and make no network requests
on CRAN. Five live API tests run only when the AIRNOW_LIVE_TESTS
environment variable is set, and are skipped on CRAN.
