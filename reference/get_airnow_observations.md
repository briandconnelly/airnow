# Get current air quality observations

`get_airnow_observations()` retrieves the most recent hourly readings
for a location. Locate it by ZIP code or latitude/longitude, or give a
reporting area code. The two forms use different AirNow services with
different methodologies:

## Usage

``` r
get_airnow_observations(
  zip = NULL,
  latitude = NULL,
  longitude = NULL,
  area = NULL,
  clean_names = TRUE,
  api_key = get_airnow_key()
)
```

## Arguments

- zip:

  ZIP code, a 5-digit numeric string (e.g., `"90210"`)

- latitude:

  Latitude in decimal degrees

- longitude:

  Longitude in decimal degrees

- area:

  Reporting area code such as `"ca064"`. See
  [airnow_areas](https://briandconnelly.github.io/airnow/reference/airnow_areas.md)
  or
  [`get_airnow_reporting_area()`](https://briandconnelly.github.io/airnow/reference/get_airnow_reporting_area.md).
  When given, `zip`, `latitude`, and `longitude` are ignored.

- clean_names:

  Whether column names should be converted to snake_case (default:
  `TRUE`). With `FALSE`, the API's lowerCamelCase names are kept.

- api_key:

  AirNow API key

## Value

A tibble with one row per pollutant. `parameter` is a factor with levels
`ozone`, `pm2.5`, `pm10`, `co`, `no2`, `so2`; `category_name` is an
ordered factor; `aqi` is the NowCast AQI.

## Details

- By ZIP code or coordinates, AirNow returns the closest reading for
  each pollutant within the reporting area's search radius, and names
  the site it came from (`site_id`, `site_name`).

- By `area`, AirNow returns the area's official value for each pollutant
  and omits the site columns, which are `NA`.

The `source` column records which service produced each row.

## Requests made

One request per call, plus one extra request (cached for the session)
when a ZIP code's reporting area shares its name with an area in another
state. There are 26 such names; see
[airnow_areas](https://briandconnelly.github.io/airnow/reference/airnow_areas.md).
All requests count against AirNow's 500-per-hour limit.

## Time columns

`hour_observed` uses AirNow's convention of labeling an hour by its
**end**: `18` means the period 17:00-17:59. `date_observed` and
`hour_observed` are local to each reporting area, and `local_time_zone`
is an abbreviation R cannot interpret. `utc_datetime` is derived from
the reporting area's metadata in
[airnow_areas](https://briandconnelly.github.io/airnow/reference/airnow_areas.md)
and marks the **end** of the observation hour (the API's label).
[`get_airnow_monitors()`](https://briandconnelly.github.io/airnow/reference/get_airnow_monitors.md)
labels the same hour by its **start** in `datetime_observed`, so to join
the two subtract one hour from `utc_datetime` (or add one hour to
`datetime_observed`). `utc_datetime` is `NA` when the area or its time
zone cannot be matched.

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_observations(zip = "90210")
get_airnow_observations(latitude = 38.3191, longitude = -122.2998)
get_airnow_observations(area = "ca064")
} # }
```
