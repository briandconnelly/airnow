# Find the AirNow reporting area for a location

`get_airnow_reporting_area()` looks up which AirNow reporting area
serves a ZIP code or a latitude/longitude pair. The returned
`reporting_area_code` is the `area` argument for
[`get_airnow_observations()`](https://briandconnelly.github.io/airnow/reference/get_airnow_observations.md),
[`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md),
and
[`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md).
Resolution uses AirNow's current-forecast service. When the area has no
forecast issued today, a ZIP code is looked up in AirNow's bundled
ZIP-to-area crosswalk instead; coordinates cannot be resolved that way,
so choose a code from
[airnow_areas](https://briandconnelly.github.io/airnow/reference/airnow_areas.md).

## Usage

``` r
get_airnow_reporting_area(
  zip = NULL,
  latitude = NULL,
  longitude = NULL,
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

- api_key:

  AirNow API key

## Value

A one-row tibble with columns `reporting_area_code`, `reporting_area`,
`state_code`, `latitude`, and `longitude`.

## Requests made

One request per distinct location per session; the result is cached in
memory, so repeated calls for the same location are free. Every request
counts against AirNow's limit of 500 requests per hour per key.

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_reporting_area(zip = "90210")
get_airnow_reporting_area(latitude = 38.3191, longitude = -122.2998)
} # }
```
