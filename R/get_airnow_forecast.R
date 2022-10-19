#' Get Air Quality Forecast
#'
#' `get_airnow_forecast()` retrieves forecasted air quality conditions
#' for the given location. Locations can be specified either by ZIP code
#' (`zip`), or by `latitude`/`longitude`. If no data exist for the specified
#' location, an optional search radius for other sites can be specified using
#' `distance`.
#'
#' @inheritParams get_airnow_conditions
#' @param date Optional date of forecast. If this is not specified, the current
#'   forecast is returned.
#'
#' @return A data frame with current air quality conditions
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_forecast(zip = "90210")
#' }
#'
get_airnow_forecast <- function(zip = NULL,
                                latitude = NULL,
                                longitude = NULL,
                                distance = NULL,
                                date = NULL,
                                clean_names = TRUE,
                                api_key = get_airnow_token()) {
  location_parsed <- check_location(zip, latitude, longitude)
  distance <- check_distance(distance)
  date <- check_date(date)

  if (!is_logical(clean_names, n = 1)) {
    cli::cli_abort("{.arg clean_names} must be either `TRUE` or `FALSE`") # nolint
  }

  result_raw <- req_airnow() |>
    httr2::req_url_path_append("forecast", location_parsed$type) |>
    httr2::req_url_query(
      zipCode = location_parsed$zip,
      latitude = location_parsed$latitude,
      longitude = location_parsed$longitude,
      format = "application/json",
      date = date,
      distance = distance,
      api_key = api_key
    ) |>
    httr2::req_perform()

  result <- result_raw |>
    httr2::resp_body_string() |>
    jsonlite::fromJSON(flatten = TRUE) |>
    tibble::as_tibble()

  result$DateIssue <- as.Date(trimws(result$DateIssue))
  result$DateForecast <- as.Date(trimws(result$DateForecast))
  result$ReportingArea <- as.factor(result$ReportingArea)
  result$StateCode <- as.factor(result$StateCode)
  result$ParameterName <- as.factor(result$ParameterName)
  result$Category.Name <- factor(
    result$Category.Name,
    levels = category_levels
  )

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}
