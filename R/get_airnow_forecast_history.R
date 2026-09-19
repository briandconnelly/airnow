#' Get past air quality forecasts
#'
#' `get_airnow_forecast_history()` retrieves forecasts that were *valid* on
#' dates in the given range for one reporting area. Every forecast lead time
#' is returned unless `range` narrows it: `range = 1` keeps only the
#' forecast issued the day before each valid date.
#'
#' @inheritParams get_airnow_forecasts
#' @param area Reporting area code such as `"ca064"` (required). See
#'   [airnow_areas] or [get_airnow_reporting_area()].
#' @param start_date,end_date First and last *valid* date to include, as
#'   `Date` objects or `"YYYY-MM-DD"` strings. AirNow serves these
#'   forecasts only through today, so a future date returns no rows and
#'   warns. Use [get_airnow_forecasts()] for upcoming forecasts.
#' @param range Optional forecast lead time in days to keep (a positive
#'   whole number). `NULL` (default) keeps every lead time.
#' @param parameter Optional pollutant to keep: one of `"ozone"`,
#'   `"pm2.5"`, `"pm10"`, `"co"`, `"no2"`, `"so2"`.
#'
#' @section Requests made:
#' One request per call. Every request counts against AirNow's limit of
#' 500 requests per hour per key.
#'
#' @return A tibble with the same columns as [get_airnow_forecasts()].
#' @seealso [get_airnow_reporting_area()] to find the area code for a ZIP
#'   code or coordinates; [get_airnow_forecasts()] for current forecasts.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14")
#' get_airnow_forecast_history("md008", "2026-01-13", "2026-01-13",
#'   range = 1, parameter = "pm2.5"
#' )
#'
#' # Starting from a ZIP code
#' area <- get_airnow_reporting_area(zip = "90210")$reporting_area_code
#' get_airnow_forecast_history(area, "2026-09-01", "2026-09-03", range = 1)
#' }
get_airnow_forecast_history <- function(area,
                                        start_date,
                                        end_date,
                                        range = NULL,
                                        parameter = NULL,
                                        clean_names = TRUE,
                                        api_key = get_airnow_key()) {
  area <- check_area_code(area)
  start_date <- check_date_arg(start_date, "start_date")
  end_date <- check_date_arg(end_date, "end_date")
  if (as.Date(start_date) > as.Date(end_date)) {
    cli::cli_abort("{.arg start_date} must not be after {.arg end_date}")
  }
  if (as.Date(end_date) > Sys.Date()) {
    cli::cli_warn("Dates in the future return no rows: AirNow's historical forecasts stop at today. Use {.fn get_airnow_forecasts} for upcoming forecasts.") # nolint
  }
  if (!is.null(range) &&
        (!is_integerish(range, n = 1) || is.na(range) || range < 1)) {
    cli::cli_abort("{.arg range} must be a single positive whole number")
  }
  if (!is.null(parameter)) {
    parameter <- toupper(arg_match(parameter, values = parameter_levels))
  }
  check_clean_names(clean_names)

  result <- req_airnow() |>
    httr2::req_url_path_append("forecast", "historical") |>
    httr2::req_url_query(
      reportingAreaCode = area,
      startDate = start_date,
      endDate = end_date,
      forecastRange = range,
      parameter = parameter,
      format = "application/json",
      api_key = api_key
    ) |>
    perform_airnow()

  finish_forecast(result, clean_names)
}
