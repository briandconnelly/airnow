# Get current air quality forecasts

`get_airnow_forecasts()` retrieves the forecasts currently issued for a
reporting area, located by ZIP code, latitude/longitude, or reporting
area code. One row is returned per pollutant per forecast day. For
forecasts valid on past dates, use
[`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md).

## Usage

``` r
get_airnow_forecasts(
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

A tibble with one row per pollutant per forecast day. `parameter` is a
factor with levels `ozone`, `pm2.5`, `pm10`, `co`, `no2`, `so2`;
`category_name` is an ordered factor from Good to Hazardous. `latitude`
and `longitude` describe the reporting area and come from
[airnow_areas](https://briandconnelly.github.io/airnow/reference/airnow_areas.md).
An `aqi` of `-1` means the agency issued a categorical forecast only.

## Requests made

One request per call. Every request counts against AirNow's limit of 500
requests per hour per key.

## See also

[`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md)
for past forecasts.

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_forecasts(zip = "90210")
get_airnow_forecasts(area = "ca064")
} # }
```
