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

  An AQI value. AQI is an integer between 0 and 500, inclusive.

## Value

`aqi_color()` returns an RGB hex string

`aqi_descriptor()` returns a string

## Examples

``` r
aqi_color(35)
#> [1] "#00E400"
aqi_descriptor(35)
#> [1] "Good"
```
