#' @rdname aqi
#' @title Label AQI Values
#'
#' @description `aqi_color()` returns the color that corresponds with the given
#' AQI value.
#'
#' @details The AQI scale nominally tops out at 500, but AirNow reports
#'   higher values during severe smoke events. Values above 500 are treated
#'   as Hazardous. `NA` inputs give `NA` outputs. Negative values (including
#'   AirNow's `-1` sentinel for a categorical forecast) give `NA` with a
#'   warning.
#'
#' @param aqi A vector of AQI values (whole numbers, `NA` allowed)
#'
#' @return `aqi_color()` returns a character vector of RGB hex strings
#' @export
#'
#' @examples
#' aqi_color(35)
#' aqi_color(c(35, NA, 874))
aqi_color <- function(aqi) {
  aqi <- check_aqi(aqi)

  colors <- rep(
    c("#00E400", "#FFFF00", "#FF7E00", "#FF0000", "#8F3F97", "#7E0023"),
    c(51, 50, 50, 50, 100, 200)
  )

  colors[pmin(aqi, 500L) + 1L]
}


#' @rdname aqi
#' @description `aqi_descriptor()` converts the given AQI value(s) into a
#'   descriptive string.
#' @return `aqi_descriptor()` returns a character vector
#' @export
#' @examples
#' aqi_descriptor(35)
aqi_descriptor <- function(aqi) {
  aqi <- check_aqi(aqi)

  descriptors <- rep(
    c(
      "Good",
      "Moderate",
      "Unhealthy for Sensitive Groups",
      "Unhealthy",
      "Very Unhealthy",
      "Hazardous"
    ),
    c(51, 50, 50, 50, 100, 200)
  )

  descriptors[pmin(aqi, 500L) + 1L]
}
