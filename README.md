
<!-- README.md is generated from README.Rmd. Please edit that file -->

# airnow

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/airnow)](https://CRAN.R-project.org/package=airnow)
[![R-CMD-check](https://github.com/briandconnelly/airnow/workflows/R-CMD-check/badge.svg)](https://github.com/briandconnelly/airnow/actions)
<!-- badges: end -->

airnow is an [R](https://www.r-project.org/) package for querying and
retrieving air quality information from
[AirNow](https://www.airnow.gov/) via the [AirNow
API](https://docs.airnowapi.org/). Current and historical readings as
well as forecasts can be retrieved as tidy data frames.

## Installation

airnow is still changing quite a bit, so it isn’t quite ready for CRAN.
You can install the development version of airnow with:

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

## Current Air Quality in Seattle

The AirNow API allows you to query air conditions either by ZIP code or
latitude/longitude. Here, we’ll get the current conditions in Seattle by
ZIP code as a data frame:

``` r
library(airnow)

get_airnow_conditions(zip = "98101")
#> # A tibble: 2 × 11
#>   date_observed hour_obs…¹ local…² repor…³ state…⁴ latit…⁵ longi…⁶ param…⁷   aqi
#>   <date>             <int> <fct>   <fct>   <fct>     <dbl>   <dbl> <fct>   <int>
#> 1 2022-10-19            15 PST     Seattl… WA         47.6   -122. O3         16
#> 2 2022-10-19            15 PST     Seattl… WA         47.6   -122. PM2.5     231
#> # … with 2 more variables: category_number <int>, category_name <fct>, and
#> #   abbreviated variable names ¹​hour_observed, ²​local_time_zone,
#> #   ³​reporting_area, ⁴​state_code, ⁵​latitude, ⁶​longitude, ⁷​parameter
```

If [tibble](https://CRAN.R-project.org/package=tibble) is installed,
airnow’s `get_airnow_` functions will return `tbl_df`s.

## Disclaimer

This package and its author are not affiliated with
[AirNow](https://www.airnow.gov/) or its
[partners](https://www.airnow.gov/partners/). See the [Data Exchange
Guidelines](https://docs.airnowapi.org/docs/DataUseGuidelines.pdf) for
more details about this data set and how it should be used. Please be
kind to this service and limit your request rate. Data are typically
refreshed once per hour.
