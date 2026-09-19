# Get air quality data from monitoring sites in a region

`get_airnow_monitors()` retrieves readings from every monitoring site
inside a bounding box. Before airnow 0.2.0 this function was called
[`get_airnow_area()`](https://briandconnelly.github.io/airnow/reference/airnow-deprecated.md).

## Usage

``` r
get_airnow_monitors(
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
```

## Arguments

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

  Whether column names should be converted to snake_case (default:
  `TRUE`). With `FALSE`, the API's PascalCase names are kept.

- api_key:

  AirNow API key

## Value

A data frame with current air quality conditions

## Examples

``` r
if (FALSE) { # \dontrun{
# Get air quality data around Washington state
get_airnow_monitors(box = c(-125.394211, 45.295897, -116.736984, 49.172497))
} # }
```
