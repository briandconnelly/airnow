# Pure transforms from the 0.2.0 tibbles back to the pre-2026 column
# contracts. Used only by the deprecated shims in R/deprecated.R.

# Canonical parameter level -> the old services' spelling
legacy_parameter_names <- c(
  ozone = "O3", pm2.5 = "PM2.5", pm10 = "PM10",
  co = "CO", no2 = "NO2", so2 = "SO2"
)


#' Convert get_airnow_observations() output to the get_airnow_conditions()
#' contract
#'
#' The old service labelled an hour by its start, the new one by its end
#' (spec section 2.3), so the hour is decremented. A `0` becomes `23` on the
#' previous date. ASSUMPTION pending the scheduled midnight probe (spec
#' section 5.1): this is the only self-consistent reading of "labelled by
#' period end", but no "00:00" response has been observed yet.
#'
#' @param x Clean-named tibble from [get_airnow_observations()]
#' @return A tibble with the 11 legacy columns
#' @noRd
observations_to_legacy <- function(x) {
  hour <- x$hour_observed - 1L
  date <- x$date_observed
  wrap <- !is.na(hour) & hour < 0L
  hour[wrap] <- 23L
  date[wrap] <- date[wrap] - 1L

  parameter <- unname(legacy_parameter_names[as.character(x$parameter)])

  tibble::tibble(
    DateObserved = date,
    HourObserved = hour,
    LocalTimeZone = as.factor(x$local_time_zone),
    ReportingArea = as.factor(x$reporting_area),
    StateCode = as.factor(x$state_code),
    Latitude = x$latitude,
    Longitude = x$longitude,
    ParameterName = as.factor(parameter),
    AQI = x$aqi,
    Category.Number = x$category_number,
    Category.Name = factor(as.character(x$category_name), levels = category_levels) # nolint
  )
}


#' Convert a clean-named forecast tibble to the get_airnow_forecast() contract
#' @param x Clean-named tibble from [get_airnow_forecasts()] or
#'   [get_airnow_forecast_history()]
#' @return A tibble with the 12 legacy columns
#' @noRd
forecasts_to_legacy <- function(x) {
  parameter <- unname(legacy_parameter_names[as.character(x$parameter)])

  tibble::tibble(
    DateIssue = x$date_issue,
    DateForecast = x$date_valid,
    ReportingArea = as.factor(x$reporting_area),
    StateCode = as.factor(x$state_code),
    Latitude = x$latitude,
    Longitude = x$longitude,
    ParameterName = as.factor(parameter),
    AQI = x$aqi,
    ActionDay = x$action_day,
    Discussion = x$discussion,
    Category.Number = x$category_number,
    Category.Name = factor(as.character(x$category_name), levels = category_levels) # nolint
  )
}
