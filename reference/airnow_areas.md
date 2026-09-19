# AirNow reporting areas

Metadata for every AirNow reporting area: its location, time zone,
agency, and the rules AirNow uses to pick monitors for it.
Reporting-area codes are the `area` argument to
[`get_airnow_observations()`](https://briandconnelly.github.io/airnow/reference/get_airnow_observations.md),
[`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md),
and
[`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md).

## Usage

``` r
airnow_areas
```

## Format

A tibble with 1,036 rows and 14 columns:

- reporting_area:

  Area name. Not unique: 26 names appear in more than one state (e.g.
  Aberdeen, SD and Aberdeen, WA).

- state_code:

  Two-letter state or province code

- country_code:

  Two-letter country code (US, CA, MX)

- latitude, longitude:

  Representative point, decimal degrees

- gmt_offset:

  Standard-time offset from UTC, in hours. AirNow's source rounds
  fractional offsets to whole hours; known half- and quarter-hour zones
  are corrected in this dataset.

- observes_dst:

  Whether the area observes daylight saving time

- tz_standard, tz_daylight:

  Time zone abbreviations as AirNow records them. Some are non-standard
  (Anchorage: `AKT`/`ADT`).

- reporting_area_code:

  Unique code, e.g. `"ca064"`

- agency:

  Agency responsible for the area

- lookup_behavior:

  How AirNow picks monitors, e.g. `"Closest Reading By Pollutant"`

- considered_monitors:

  Which monitors are eligible

- lookup_boundary:

  Search radius, e.g. `"50 miles"`; `NA` when AirNow leaves it blank

## Source

AirNow reporting area metadata,
<https://files.airnowtech.org/airnow/today/reportingarea_metadata.dat>,
retrieved 2026-09-12. AirNow is a partnership of the U.S. EPA, NOAA,
NPS, tribal, state, and local agencies; the file is published without
access restrictions. One exact duplicate row (Monterrey, `mx002`) was
removed. Rebuild with `data-raw/airnow_areas.R`.

## Details

Reporting areas are occasionally added, renamed, or retired between
package releases, so a live response can name an area missing from this
table. Functions that join against it warn when that happens and leave
the geography columns `NA`.
