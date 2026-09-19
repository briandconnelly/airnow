# Deprecated functions

These functions were deprecated in airnow 0.2.0 and will be removed in a
future release. Each one warns and then calls its replacement.

|  |  |
|----|----|
| Deprecated | Replacement |
| `get_airnow_token()` | [`get_airnow_key()`](https://briandconnelly.github.io/airnow/reference/get_airnow_key.md) |
| `set_airnow_token()` | [`set_airnow_key()`](https://briandconnelly.github.io/airnow/reference/get_airnow_key.md) |
| `get_airnow_area()` | [`get_airnow_monitors()`](https://briandconnelly.github.io/airnow/reference/get_airnow_monitors.md) |
| `get_airnow_conditions()` | [`get_airnow_observations()`](https://briandconnelly.github.io/airnow/reference/get_airnow_observations.md) |
| `get_airnow_forecast()` | [`get_airnow_forecasts()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecasts.md) |
| `get_airnow_forecast(date = )` | [`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md) |

## Usage

``` r
get_airnow_token(ask = is_interactive())

set_airnow_token(token = NULL, ask = is_interactive())

get_airnow_area(
  box,
  parameters = "pm25",
  start_time = NULL,
  end_time = NULL,
  monitor_type = "both",
  data_type = c("aqi", "concentrations", "both"),
  verbose = FALSE,
  raw_concentrations = FALSE,
  clean_names = TRUE,
  api_key = get_airnow_key()
)

get_airnow_conditions(
  zip = NULL,
  latitude = NULL,
  longitude = NULL,
  distance = NULL,
  clean_names = TRUE,
  api_key = get_airnow_key()
)

get_airnow_forecast(
  zip = NULL,
  latitude = NULL,
  longitude = NULL,
  distance = NULL,
  date = NULL,
  clean_names = TRUE,
  api_key = get_airnow_key(),
  area = NULL
)
```

## Arguments

- ask:

  Whether to prompt for the key if none is set. Prompting only works in
  interactive sessions.

- token:

  The API key to use (deprecated spelling of `key`)

- box:

  Four-element numeric vector specifying a bounding box for the region
  of interest. Format is (minX, minY, maxX, maxY), where X and Y are
  longitude and latitude, respectively.

- parameters:

  Parameter(s) to return data for. Choices are PM\_{2.5} (`pm25`:
  default), `ozone`, PM_10 (`pm10`), CO (`co`), NO2 (`no2`), and SO2
  (`so2`).

- start_time:

  Optional. The date and time (UTC) at the start of the time period
  requested. If specified, `end_time` must also be given. If not
  specified, the most recent past hour is used.

- end_time:

  Optional. The date and time (UTC) at the end of the time period
  requested. If specified, `start_time` must also be given. If not
  specified, the following hour is used.

- monitor_type:

  Type of monitor to be returned, either `"permanent"`, `"mobile"`, or
  `"both"` (default).

- data_type:

  Type of data to be returned, either `"aqi"` (default),
  `"concentrations"`, or `"both"`.

- verbose:

  Logical value indicating whether or not to include additional site
  information including Site Name, Agency Name, AQS ID, and Full AQS ID
  (default: `FALSE`)

- raw_concentrations:

  Logical value indicating whether or not raw hourly concentration data
  should be included (default: `FALSE`)

- clean_names:

  Whether or not column names should be cleaned (default: `TRUE`)

- api_key:

  AirNow API key

- zip:

  ZIP code, a 5-digit numeric string (e.g., `"90210"`)

- latitude:

  Latitude in decimal degrees

- longitude:

  Longitude in decimal degrees

- distance:

  Ignored since airnow 0.2.0. The 2026 AirNow services search a fixed
  radius for each reporting area.

- date:

  Optional date of forecast as a `"YYYY-MM-DD"` string. Since airnow
  0.2.0 this returns forecasts *valid* on that date with a one-day lead
  time; the old service also returned forecasts *issued* on that date.
  Use
  [`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md)
  in new code.

- area:

  Optional reporting area code such as `"ca064"`. This is an additive
  compatibility argument and must not be combined with `zip`,
  `latitude`, `longitude`, or `distance`. Prefer
  [`get_airnow_forecast_history()`](https://briandconnelly.github.io/airnow/reference/get_airnow_forecast_history.md)
  for new code.

## Value

The token/key and area/monitor aliases return the value from their
replacement. `get_airnow_conditions()` and `get_airnow_forecast()`
return tibbles reshaped to their legacy 11- and 12-column contracts.
