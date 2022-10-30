
<!-- README.md is generated from README.Rmd. Please edit that file -->

# airnow

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/airnow)](https://CRAN.R-project.org/package=airnow)
[![R-CMD-check](https://github.com/briandconnelly/airnow/workflows/R-CMD-check/badge.svg)](https://github.com/briandconnelly/airnow/actions)
[![Codecov test
coverage](https://codecov.io/gh/briandconnelly/airnow/branch/main/graph/badge.svg)](https://app.codecov.io/gh/briandconnelly/airnow?branch=main)
<!-- badges: end -->

airnow is an [R](https://www.r-project.org/) package for querying and
retrieving air quality information from
[AirNow](https://www.airnow.gov/) via the [AirNow
API](https://docs.airnowapi.org/). Current and historical readings as
well as forecasts can be retrieved as tidy data frames.

## Installation

You can install the stable version of airnow from CRAN:

``` r
install.packages("airnow")
```

If you’d like to try out the development version of airnow, you can
install directly from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("briandconnelly/airnow")
```

## Creating an API Token

The [AirNow API](https://docs.airnowapi.org/) is generally free to use.
The `set_airnow_token()` function can be used to help you create and
configure your API token.

``` r
library(airnow)

set_airnow_token()
```

## Examples

### Current air quality in Seattle

The AirNow API allows you to query air conditions either by ZIP code or
latitude/longitude. Here, we’ll get the current conditions in Seattle by
ZIP code:

``` r
library(airnow)

get_airnow_conditions(zip = "98101")
#> # A tibble: 2 × 11
#>   date_observed hour_obs…¹ local…² repor…³ state…⁴ latit…⁵ longi…⁶ param…⁷   aqi
#>   <date>             <int> <fct>   <fct>   <fct>     <dbl>   <dbl> <fct>   <int>
#> 1 2022-10-29            17 PST     Seattl… WA         47.6   -122. O3         25
#> 2 2022-10-29            17 PST     Seattl… WA         47.6   -122. PM2.5      38
#> # … with 2 more variables: category_number <int>, category_name <fct>, and
#> #   abbreviated variable names ¹​hour_observed, ²​local_time_zone,
#> #   ³​reporting_area, ⁴​state_code, ⁵​latitude, ⁶​longitude, ⁷​parameter
```

### Find the site with the lowest air quality near Washington state

``` r
library(airnow)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union

get_airnow_area(
  box = c(-125.394211, 45.295897, -116.736984, 49.172497),
  verbose = TRUE
) |>
  slice_max(order_by = aqi, n = 1) |>
  select(site_name, site_agency, latitude, longitude, aqi, datetime_observed)
#> # A tibble: 1 × 6
#>   site_name            site_agency     latit…¹ longi…²   aqi datetime_observed  
#>   <fct>                <fct>             <dbl>   <dbl> <int> <dttm>             
#> 1 Chehalis-Market Blvd Washington Dep…    46.7   -123.   129 2022-10-30 00:00:00
#> # … with abbreviated variable names ¹​latitude, ²​longitude
```

## Disclaimer

This package and its author are not affiliated with
[AirNow](https://www.airnow.gov/) or its
[partners](https://www.airnow.gov/partners/). See the [Data Exchange
Guidelines](https://docs.airnowapi.org/docs/DataUseGuidelines.pdf) for
more details about this data set and how it should be used. Data are
typically refreshed once per hour. Please be kind to this service and
limit your request rate.
