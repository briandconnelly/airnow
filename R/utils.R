#' Convert lowerCamelCase to snake_case
#'
#' Handles runs of capitals: `nowcastAQI` -> `nowcast_aqi`,
#' `dailyAQICategoryName` -> `daily_aqi_category_name`.
#'
#' @param x Character vector of names
#' @return Character vector
#' @noRd
camel_to_snake <- function(x) {
  x <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  x <- gsub("([A-Z]+)([A-Z][a-z])", "\\1_\\2", x)
  tolower(x)
}


clean_names <- function(x) {
  if (!is_named(x)) {
    cli::cli_abort("Object must have a {.field names} attribute")
  }

  # Explicit mappings win. Legacy (pre-2026) names first, then the names the
  # 2026 services use where the generic conversion would be wrong or ugly.
  name_mapping <- c(
    "DateObserved" = "date_observed",
    "HourObserved" = "hour_observed",
    "LocalTimeZone" = "local_time_zone",
    "ReportingArea" = "reporting_area",
    "StateCode" = "state_code",
    "Latitude" = "latitude",
    "Longitude" = "longitude",
    "ParameterName" = "parameter",
    "AQI" = "aqi",
    "Category.Number" = "category_number",
    "Category.Name" = "category_name",
    "DateIssue" = "date_issued",
    "DateForecast" = "date_forecast",
    "ActionDay" = "action_day",
    "Discussion" = "discussion",
    "UTC" = "datetime_observed",
    "Parameter" = "parameter",
    "Unit" = "unit",
    "Value" = "value",
    "RawConcentration" = "raw_concentration",
    "Category" = "category_number",
    "SiteName" = "site_name",
    "AgencyName" = "site_agency",
    "FullAQSCode" = "aqs_code",
    "IntlAQSCode" = "intl_aqs_code",
    "parameterName" = "parameter",
    "reportingAreaName" = "reporting_area",
    "nowcastAQI" = "aqi",
    "aqiCategoryName" = "category_name",
    "dailyAQI" = "aqi",
    "dailyAQICategoryName" = "category_name",
    "siteID" = "site_id"
  )

  nms <- names(x)
  mapped <- nms %in% names(name_mapping)
  nms[mapped] <- unname(name_mapping[nms[mapped]])
  nms[!mapped] <- camel_to_snake(nms[!mapped])
  names(x) <- nms
  x
}
