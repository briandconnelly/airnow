#' Deprecated functions
#'
#' @description These functions were deprecated in airnow 0.2.0 and will be
#'   removed in a future release. Each one warns and then calls its
#'   replacement.
#'
#' | Deprecated | Replacement |
#' |---|---|
#' | `get_airnow_token()` | [get_airnow_key()] |
#' | `set_airnow_token()` | [set_airnow_key()] |
#' | `get_airnow_area()` | [get_airnow_monitors()] |
#' | `get_airnow_conditions()` | [get_airnow_observations()] |
#' | `get_airnow_forecast()` | [get_airnow_forecasts()] |
#'
#' @return Each deprecated function returns whatever its replacement returns.
#' @name airnow-deprecated
#' @keywords internal
NULL


#' @rdname airnow-deprecated
#' @inheritParams get_airnow_key
#' @export
get_airnow_token <- function(ask = is_interactive()) {
  lifecycle::deprecate_warn("0.2.0", "get_airnow_token()", "get_airnow_key()")
  get_airnow_key(ask = ask)
}


#' @rdname airnow-deprecated
#' @param token The API key to use (deprecated spelling of `key`)
#' @export
set_airnow_token <- function(token = NULL, ask = is_interactive()) {
  lifecycle::deprecate_warn("0.2.0", "set_airnow_token()", "set_airnow_key()")
  set_airnow_key(key = token, ask = ask)
}


#' @rdname airnow-deprecated
#' @inheritParams get_airnow_monitors
#' @export
get_airnow_area <- function(box,
                            parameters = "pm25",
                            start_time = NULL,
                            end_time = NULL,
                            monitor_type = "both",
                            data_type = c("aqi", "concentrations", "both"),
                            verbose = FALSE,
                            raw_concentrations = FALSE,
                            clean_names = TRUE,
                            api_key = get_airnow_key()) {
  lifecycle::deprecate_warn("0.2.0", "get_airnow_area()", "get_airnow_monitors()") # nolint
  get_airnow_monitors(
    box = box,
    parameters = parameters,
    start_time = start_time,
    end_time = end_time,
    monitor_type = monitor_type,
    data_type = data_type,
    verbose = verbose,
    raw_concentrations = raw_concentrations,
    clean_names = clean_names,
    api_key = api_key
  )
}


#' @rdname airnow-deprecated
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param distance Ignored since airnow 0.2.0. The 2026 AirNow services
#'   search a fixed radius for each reporting area.
#' @param clean_names Whether or not column names should be cleaned
#'   (default: `TRUE`)
#' @param api_key AirNow API key
#' @export
get_airnow_conditions <- function(zip = NULL,
                                  latitude = NULL,
                                  longitude = NULL,
                                  distance = NULL,
                                  clean_names = TRUE,
                                  api_key = get_airnow_key()) {
  location <- check_location(zip, latitude, longitude)
  distance <- check_distance(distance)
  check_clean_names(clean_names)

  lifecycle::deprecate_warn(
    "0.2.0", "get_airnow_conditions()", "get_airnow_observations()",
    details = c(
      "AirNow retires the service behind this function on 2026-09-30.",
      "This shim calls the replacement service and reshapes the result. Row counts and AQI values may differ from before; LocalTimeZone is now correct; HourObserved keeps the old start-of-hour convention." # nolint
    )
  )
  if (!is.null(distance)) {
    cli::cli_warn("{.arg distance} is ignored: the AirNow API now searches a fixed radius for each reporting area") # nolint
  }

  result <- get_airnow_observations(
    zip = location$zip,
    latitude = location$latitude,
    longitude = location$longitude,
    clean_names = TRUE,
    api_key = api_key
  )
  result <- observations_to_legacy(result)

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}


#' @rdname airnow-deprecated
#' @param date Optional date of forecast as a `"YYYY-MM-DD"` string. Since
#'   airnow 0.2.0 this returns forecasts *valid* on that date with a
#'   one-day lead time; the old service also returned forecasts *issued* on
#'   that date.
#' @export
get_airnow_forecast <- function(zip = NULL,
                                latitude = NULL,
                                longitude = NULL,
                                distance = NULL,
                                date = NULL,
                                clean_names = TRUE,
                                api_key = get_airnow_key()) {
  location <- check_location(zip, latitude, longitude)
  distance <- check_distance(distance)
  date <- check_date(date)
  if (!is.null(date)) date <- check_date_arg(date, "date")
  check_clean_names(clean_names)

  lifecycle::deprecate_warn(
    "0.2.0", "get_airnow_forecast()", "get_airnow_forecasts()",
    details = c(
      "AirNow retires the service behind this function on 2026-09-30.",
      "This shim calls the replacement service and reshapes the result. Row counts may differ; `date` now selects forecasts valid on that date only." # nolint
    )
  )
  if (!is.null(distance)) {
    cli::cli_warn("{.arg distance} is ignored: the AirNow API now searches a fixed radius for each reporting area") # nolint
  }

  if (is.null(date)) {
    result <- get_airnow_forecasts(
      zip = location$zip,
      latitude = location$latitude,
      longitude = location$longitude,
      clean_names = TRUE,
      api_key = api_key
    )
  } else {
    area <- resolve_area_code(
      zip = location$zip,
      latitude = location$latitude,
      longitude = location$longitude,
      api_key = api_key
    )
    result <- get_airnow_forecast_history(
      area = area,
      start_date = date,
      end_date = date,
      range = 1,
      clean_names = TRUE,
      api_key = api_key
    )
  }
  result <- forecasts_to_legacy(result)

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}
