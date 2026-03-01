# Get air quality forecast

`get_airnow_forecast()` retrieves forecasted air quality conditions for
the given location. Locations can be specified either by ZIP code
(`zip`), or by `latitude`/`longitude`. If no data exist for the
specified location, an optional search radius for other sites can be
specified using `distance`.

## Usage

``` r
get_airnow_forecast(
  zip = NULL,
  latitude = NULL,
  longitude = NULL,
  distance = NULL,
  date = NULL,
  clean_names = TRUE,
  api_key = get_airnow_token()
)
```

## Arguments

- zip:

  ZIP code, a 5-digit numeric string (e.g., `"90210"`)

- latitude:

  Latitude in decimal degrees

- longitude:

  Longitude in decimal degrees

- distance:

  Optional. If no reporting area is associated with the given `zip`
  code, current observations from a nearby reporting area within this
  distance (in miles) will be returned, if available.

- date:

  Optional date of forecast. If this is not specified, the current
  forecast is returned.

- clean_names:

  Whether or not column names should be cleaned (default: `TRUE`)

- api_key:

  AirNow API key

## Value

A data frame with current air quality conditions

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_forecast(zip = "90210")
} # }
```
