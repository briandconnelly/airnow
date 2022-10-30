#' @rdname aqi
#' @title Label AQI Values
#'
#' @description `aqi_color()` returns the color that corresponds with the given
#' AQI value.
#'
#' @param aqi An AQI value. AQI is an integer between 0 and 500, inclusive.
#'
#' @return `aqi_color()` returns an RGB hex string
#' @export
#'
#' @examples
#' aqi_color(35)
aqi_color <- function(aqi) {
  aqi <- check_aqi(aqi)

  colors <- rep(
    c("#00E400", "#FFFF00", "#FF7E00", "#FF0000", "#8F3F97", "#7E0023"),
    c(51, 50, 50, 50, 100, 200)
  )

  colors[(aqi + 1)]
}


#' @rdname aqi
#' @description `aqi_descriptor()` converts the given AQI value(s) into a
#'   descriptive string.
#' @return `aqi_descriptor()` returns a string
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

  descriptors[(aqi + 1)]
}
