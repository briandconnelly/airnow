#' Get air quality data for a given region
#'
#' `get_airnow_area()` retrieves the most recent air quality readings from sites
#' in a specified region.
#'
#' @inheritParams get_airnow_conditions
#' @param box Four-element numeric vector specifying a bounding box for the
#'   region of interest. Format is (minX, minY, maxX, maxY), where X and Y are
#'   longitude and latitude, respectively.
#' @param parameters Parameter(s) to return data for. Choices are PM_{2.5}
#'   (`pm25`: default), `ozone`, PM_10 (`pm10`), CO (`co`), NO2 (`no2`), and
#'   SO2 (`so2`).
#' @param start_time Optional. The date and time (UTC) at the start of the time
#'   period requested. If specified, `end_time` must also be given. If not
#'   specified, the most recent past hour is used.
#' @param end_time Optional. The date and time (UTC) at the end of the time
#'   period requested. If specified, `start_time` must also be given. If not
#'   specified, the following hour is used.
#' @param monitor_type Type of monitor to be returned, either `"permanent"`,
#'   `"mobile"`, or `"both"` (default).
#' @param data_type Type of data to be returned, either `"aqi"` (default),
#'   `"concentrations"`, or `"both"`.
#' @param verbose Logical value indicating whether or not to include additional
#'   site information including Site Name, Agency Name, AQS ID, and Full AQS ID
#'   (default: `FALSE`)
#' @param raw_concentrations Logical value indicating whether or not raw
#'   hourly concentration data should be included (default: `FALSE`)
#'
#' @return A data frame with current air quality conditions
#' @export
#'
#' @examples
#' \dontrun{
#' # Get air quality data around Washington state
#' get_airnow_area(box = c(-125.394211, 45.295897, -116.736984, 49.172497))
#' }
get_airnow_area <- function(box,
                            parameters = "pm25",
                            start_time = NULL,
                            end_time = NULL,
                            monitor_type = "both",
                            data_type = c("aqi", "concentrations", "both"),
                            verbose = FALSE,
                            raw_concentrations = FALSE,
                            clean_names = TRUE,
                            api_key = get_airnow_token()) {
  box <- check_bounding_box(box)

  parameters <- arg_match(
    parameters,
    values = c("pm25", "ozone", "pm10", "co", "no2", "so2"),
    multiple = TRUE
  )

  date_check <- c(!is.null(start_time), !is.null(end_time))
  if (any(date_check) && !all(date_check)) {
    cli::cli_abort("Both {.arg start_time} and {.arg end_time} must be specified") # nolint
  } else if (all(date_check)) {
    # TODO: validate dates
    # TODO: make sure start_date <= end_date
  }

  monitor_type <- switch(arg_match(monitor_type),
    "both" = 0,
    "permanent" = 1,
    "mobile" = 2
  )

  data_type <- switch(arg_match(data_type),
    "aqi" = "A",
    "concentrations" = "C",
    "both" = "B"
  )

  if (!is_logical(verbose, n = 1)) {
    cli::cli_abort("{.arg verbose} must be either `TRUE` or `FALSE`")
  }

  if (!is_logical(raw_concentrations, n = 1)) {
    cli::cli_abort("{.arg raw_concentrations} must be either `TRUE` or `FALSE`") # nolint
  }

  if (!is_logical(clean_names, n = 1)) {
    cli::cli_abort("{.arg clean_names} must be either `TRUE` or `FALSE`") # nolint
  }

  if (!is_string(api_key) || nchar(api_key) < 1) {
    cli::cli_abort("{.arg api_key} must be a string")
  }

  result_raw <- req_airnow() |>
    httr2::req_url_path_append("data/") |>
    httr2::req_url_query(
      bbox = paste0(box, collapse = ","),
      startdate = start_time,
      enddate = end_time,
      parameters = paste0(parameters, collapse = ","),
      monitortype = monitor_type,
      datatype = data_type,
      format = "application/json",
      api_key = get_airnow_token(),
      verbose = as.integer(verbose),
      includerawconcentrations = as.integer(raw_concentrations)
    ) |>
    httr2::req_perform()

  result <- result_raw |>
    httr2::resp_body_string() |>
    jsonlite::fromJSON(flatten = TRUE) |>
    tibble::as_tibble()

  result$UTC <- strptime(result$UTC, format = "%Y-%m-%dT%H:%M", tz = "UTC")
  result$Parameter <- as.factor(result$Parameter)
  result$Unit <- as.factor(result$Unit)
  if (verbose) {
    result$SiteName <- as.factor(result$SiteName)
    result$AgencyName <- as.factor(result$AgencyName)
  }

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}
