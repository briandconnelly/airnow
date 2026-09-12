#' Find the AirNow reporting area for a location
#'
#' `get_airnow_reporting_area()` looks up which AirNow reporting area serves
#' a ZIP code or a latitude/longitude pair. The returned
#' `reporting_area_code` is the `area` argument for
#' [get_airnow_observations()], [get_airnow_forecasts()], and
#' [get_airnow_forecast_history()]. Resolution uses AirNow's
#' current-forecast service, so it requires the area to have a forecast
#' issued for today; areas without one cannot be resolved this way.
#'
#' @section Requests made:
#' One request per distinct location per session; the result is cached in
#' memory, so repeated calls for the same location are free. Every request
#' counts against AirNow's limit of 500 requests per hour per key.
#'
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param api_key AirNow API key
#'
#' @return A one-row tibble with columns `reporting_area_code`,
#'   `reporting_area`, `state_code`, `latitude`, and `longitude`.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_reporting_area(zip = "90210")
#' get_airnow_reporting_area(latitude = 38.3191, longitude = -122.2998)
#' }
get_airnow_reporting_area <- function(zip = NULL,
                                      latitude = NULL,
                                      longitude = NULL,
                                      api_key = get_airnow_key()) {
  code <- resolve_area_code(
    zip = zip, latitude = latitude, longitude = longitude, api_key = api_key
  )

  areas <- areas_table()
  area <- areas[areas$reporting_area_code == code, , drop = FALSE]

  if (nrow(area) != 1) {
    cli::cli_warn("Reporting area code {.val {code}} not found in {.field airnow_areas}; returning the code only") # nolint
    return(tibble::tibble(
      reporting_area_code = code,
      reporting_area = NA_character_,
      state_code = NA_character_,
      latitude = NA_real_,
      longitude = NA_real_
    ))
  }

  area[, c("reporting_area_code", "reporting_area", "state_code", "latitude", "longitude")] # nolint
}
