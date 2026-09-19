# Get past air quality forecasts

`get_airnow_forecast_history()` retrieves forecasts that were *valid* on
dates in the given range for one reporting area. Every forecast lead
time is returned unless `range` narrows it: `range = 1` keeps only the
forecast issued the day before each valid date.

## Usage

``` r
get_airnow_forecast_history(
  area,
  start_date,
  end_date,
  range = NULL,
  parameter = NULL,
  clean_names = TRUE,
  api_key = get_airnow_key()
)
```

## Arguments

- area:

  Reporting area code such as `"ca064"` (required). See
  [airnow_areas](https://briandconnelly.github.io/airnow/reference/airnow_areas.md)
  or
  [`get_airnow_reporting_area()`](https://briandconnelly.github.io/airnow/reference/get_airnow_reporting_area.md).

- start_date, end_date:

  First and last *valid* date to include, as `Date` objects or
  `"YYYY-MM-DD"` strings. AirNow serves these forecasts only through
  today, so a future date returns no rows and warns. Use
  [`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md)
  for upcoming forecasts.

- range:

  Optional forecast lead time in days to keep (a positive whole number).
  `NULL` (default) keeps every lead time.

- parameter:

  Optional pollutant to keep: one of `"ozone"`, `"pm2.5"`, `"pm10"`,
  `"co"`, `"no2"`, `"so2"`.

- clean_names:

  Whether column names should be converted to snake_case (default:
  `TRUE`). With `FALSE`, the API's lowerCamelCase names are kept.

- api_key:

  AirNow API key

## Value

A tibble with the same columns as
[`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md).

## Requests made

One request per call. Every request counts against AirNow's limit of 500
requests per hour per key.

## See also

[`get_airnow_reporting_area()`](https://briandconnelly.github.io/airnow/reference/get_airnow_reporting_area.md)
to find the area code for a ZIP code or coordinates;
[`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md)
for current forecasts.

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14")
get_airnow_forecast_history("md008", "2026-01-13", "2026-01-13",
  range = 1, parameter = "pm2.5"
)

# Starting from a ZIP code
area <- get_airnow_reporting_area(zip = "90210")$reporting_area_code
get_airnow_forecast_history(area, "2026-09-01", "2026-09-03", range = 1)
} # }
```
