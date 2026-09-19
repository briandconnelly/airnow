# Label AQI Values

`aqi_color()` returns the color that corresponds with the given AQI
value.

`aqi_descriptor()` converts the given AQI value(s) into a descriptive
string.

## Usage

``` r
aqi_color(aqi)

aqi_descriptor(aqi)
```

## Arguments

- aqi:

  A vector of AQI values (whole numbers, `NA` allowed)

## Value

`aqi_color()` returns a character vector of RGB hex strings

`aqi_descriptor()` returns a character vector

## Details

The AQI scale nominally tops out at 500, but AirNow reports higher
values during severe smoke events. Values above 500 are treated as
Hazardous. `NA` inputs give `NA` outputs. Negative values (including
AirNow's `-1` sentinel for a categorical forecast) give `NA` with a
warning.

## Examples

``` r
aqi_color(35)
#> [1] "#00E400"
aqi_color(c(35, NA, 874))
#> [1] "#00E400" NA        "#7E0023"
aqi_descriptor(35)
#> [1] "Good"
```
