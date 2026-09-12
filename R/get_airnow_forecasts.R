# Contract for forecast tibbles (raw API names). Typed NA per column.
forecast_columns <- list(
  dateIssue = as.Date(NA),
  dateValid = as.Date(NA),
  reportingArea = NA_character_,
  reportingAreaCode = NA_character_,
  stateCode = NA_character_,
  latitude = NA_real_,
  longitude = NA_real_,
  parameterName = NA_character_,
  aqi = NA_integer_,
  categoryNumber = NA_integer_,
  categoryName = NA_character_,
  actionDay = NA,
  discussion = NA_character_,
  forecastAgency = NA_character_
)


#' Normalize a forecast payload from either forecast service
#' @param x Tibble from [perform_airnow()], possibly 0x0
#' @param clean_names Whether to convert names to snake_case
#' @return A tibble following `forecast_columns`
#' @noRd
finish_forecast <- function(x, clean_names) {
  if (nrow(x) > 0) {
    x$dateIssue <- as.Date(trimws(x$dateIssue))
    x$dateValid <- as.Date(trimws(x$dateValid))
    x$parameterName <- to_parameter_factor(x$parameterName)
    x$categoryName <- to_category_factor(x$categoryName)
    x$categoryNumber <- as.integer(x$categoryNumber)
    x$aqi <- as.integer(x$aqi)
    x$actionDay <- as.logical(x$actionDay)
    x <- join_areas_by_code(x)
  }
  x <- add_missing_columns(x, forecast_columns)
  if (nrow(x) == 0) {
    x$parameterName <- to_parameter_factor(character(0))
    x$categoryName <- to_category_factor(character(0))
  }
  if (clean_names) {
    x <- clean_names(x)
  }
  x
}


#' Get current air quality forecasts
#'
#' `get_airnow_forecasts()` retrieves the forecasts currently issued for a
#' reporting area, located by ZIP code, latitude/longitude, or reporting
#' area code. One row is returned per pollutant per forecast day.
#'
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param area Reporting area code such as `"ca064"`. See [airnow_areas] or
#'   [get_airnow_reporting_area()]. When given, `zip`, `latitude`, and
#'   `longitude` are ignored.
#' @param clean_names Whether column names should be converted to snake_case
#'   (default: `TRUE`). With `FALSE`, the API's lowerCamelCase names are kept.
#' @param api_key AirNow API key
#'
#' @section Requests made:
#' One request per call. Every request counts against AirNow's limit of
#' 500 requests per hour per key.
#'
#' @return A tibble with one row per pollutant per forecast day. `parameter`
#'   is a factor with levels `ozone`, `pm2.5`, `pm10`, `co`, `no2`, `so2`;
#'   `category_name` is an ordered factor from Good to Hazardous. `latitude`
#'   and `longitude` describe the reporting area and come from [airnow_areas].
#'   An `aqi` of `-1` means the agency issued a categorical forecast only.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_forecasts(zip = "90210")
#' get_airnow_forecasts(area = "ca064")
#' }
get_airnow_forecasts <- function(zip = NULL,
                                 latitude = NULL,
                                 longitude = NULL,
                                 area = NULL,
                                 clean_names = TRUE,
                                 api_key = get_airnow_key()) {
  query <- check_area_or_location(zip, latitude, longitude, area)
  check_clean_names(clean_names)

  result <- req_airnow() |>
    httr2::req_url_path_append("forecast", "current") |>
    httr2::req_url_query(
      zipCode = query$zip,
      latitude = query$latitude,
      longitude = query$longitude,
      reportingAreaCode = query$area,
      format = "application/json",
      api_key = api_key
    ) |>
    perform_airnow()

  finish_forecast(result, clean_names)
}
