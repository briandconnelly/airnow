clean_names <- function(x) {
  if (!is_named(x)) {
    cli::cli_abort("Object must have a {.field names} attribute")
  }

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
    "ReportingArea" = "reporting_area",
    "ActionDay" = "action_day",
    "Discussion" = "discussion",
    "UTC" = "datetime_observed",
    "ParameterName" = "parameter",
    "Parameter" = "parameter",
    "Unit" = "unit",
    "Value" = "value",
    "RawConcentration" = "raw_concentration",
    "Category" = "category_number",
    "SiteName" = "site_name",
    "AgencyName" = "site_agency",
    "FullAQSCode" = "aqs_code",
    "IntlAQSCode" = "intl_aqs_code"
  )

  names(x)[names(x) %in% names(name_mapping)] <- name_mapping[names(x)]
  x
}
