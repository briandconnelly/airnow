# Changelog

## airnow 0.2.0

AirNow retires the web services behind
[`get_airnow_conditions()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md)
and
[`get_airnow_forecast()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md)
on 2026-09-30. This release moves the package to the replacement
services released in June 2026.

### New functions

- [`get_airnow_observations()`](https://briandconnelly.github.io/airnow/reference/get_airnow_observations.md)
  returns current readings by ZIP code, coordinates, or reporting area
  code, with a derived `utc_datetime` column.
- [`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md)
  returns the forecasts currently issued for a location.
- [`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md)
  returns past forecasts for a reporting area and date range. It
  replaces `get_airnow_forecast(date = )`.
- [`get_airnow_reporting_area()`](https://briandconnelly.github.io/airnow/reference/get_airnow_reporting_area.md)
  finds the reporting area that serves a location. ZIP codes whose area
  has no forecast issued today fall back to AirNow’s bundled ZIP
  crosswalk.
- [`get_airnow_monitors()`](https://briandconnelly.github.io/airnow/reference/get_airnow_monitors.md)
  is the new name for
  [`get_airnow_area()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md).
- [`get_airnow_key()`](https://briandconnelly.github.io/airnow/reference/get_airnow_key.md)
  and
  [`set_airnow_key()`](https://briandconnelly.github.io/airnow/reference/get_airnow_key.md)
  replace the token-named credential helpers.

### New dataset

- `airnow_areas` lists every AirNow reporting area with its code,
  location, time zone, and agency.

### Deprecations

- [`get_airnow_conditions()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md),
  [`get_airnow_forecast()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md),
  [`get_airnow_area()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md),
  [`get_airnow_token()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md),
  and
  [`set_airnow_token()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md)
  still work but warn. The first two call the new services and reshape
  the result to their old columns. Row counts and AQI values can differ
  from the retired services because AirNow changed its lookup
  methodology; `LocalTimeZone` is now correct where it was wrong before;
  `distance` is ignored; and `get_airnow_forecast(date = )` returns
  forecasts valid on that date only. Dated calls for ZIPs in AirNow’s
  bundled crosswalk no longer depend on a forecast being issued today.
  The additive `area` argument provides an exact fallback for
  coordinates and ZIPs absent from the crosswalk while preserving the
  legacy output columns.

### Fixes

- Requests use HTTPS. Previously the API key made its first hop over
  plain HTTP before a redirect.
- API error messages are reported instead of a malformed data frame.
  Requests that match no data return a zero-row tibble.
- [`aqi_color()`](https://briandconnelly.github.io/airnow/reference/aqi.md)
  and
  [`aqi_descriptor()`](https://briandconnelly.github.io/airnow/reference/aqi.md)
  accept values above 500 (treated as Hazardous) and `NA`, and warn
  instead of erroring on negative values. Real AirNow data exceeds 500
  during smoke events.
- Unrecognized pollutant or category names now warn instead of silently
  becoming `NA`.
- Derived UTC observation times account for half- and quarter-hour time
  zones.

## airnow 0.1.1

CRAN release: 2026-03-01

Fix issue with documentation - thanks
[@GeraldineGomez](https://github.com/GeraldineGomez)!
([\#6](https://github.com/briandconnelly/airnow/issues/6))

## airnow 0.1.0

CRAN release: 2022-10-31

- Initial release
