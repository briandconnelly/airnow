#' Get current air quality conditions
#'
#' `get_airnow_conditions()` retrieves the most recent air quality readings
#' for the given location. Locations can be specified either by ZIP code
#' (`zip`), or by `latitude`/`longitude`. If no data exist for the specified
#' location, an optional search radius for other sites can be specified using
#' `distance`.
#'
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param distance Optional. If no reporting area is associated with the given
#'   `zip` code, current observations from a nearby reporting area within this
#'   distance (in miles) will be returned, if available.
#' @param clean_names Whether or not column names should be cleaned (default:
#'   `TRUE`)
#' @param api_key AirNow API key
#'
#' @return A data frame with current air quality conditions
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_conditions(zip = "90210")
#' }
#'
get_airnow_conditions <- function(zip = NULL,
                                  latitude = NULL,
                                  longitude = NULL,
                                  distance = NULL,
                                  clean_names = TRUE,
                                  api_key = get_airnow_token()) {
  location_parsed <- check_location(zip, latitude, longitude)
  distance <- check_distance(distance)

  if (!is_logical(clean_names, n = 1)) {
    cli::cli_abort("{.arg clean_names} must be either `TRUE` or `FALSE`") # nolint
  }

  result_raw <- req_airnow() |>
    httr2::req_url_path_append(
      "observation",
      location_parsed$type,
      "current"
    ) |>
    httr2::req_url_query(
      zipCode = location_parsed$zip,
      latitude = location_parsed$latitude,
      longitude = location_parsed$longitude,
      format = "application/json",
      distance = distance,
      api_key = api_key
    ) |>
    httr2::req_perform()

  result <- result_raw |>
    httr2::resp_body_string() |>
    jsonlite::fromJSON(flatten = TRUE) |>
    tibble::as_tibble()

  if (nrow(result) > 0) {
    result$DateObserved <- as.Date(trimws(result$DateObserved))
    result$LocalTimeZone <- as.factor(result$LocalTimeZone)
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
  }

  result
}
