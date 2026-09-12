#' AirNow reporting areas
#'
#' Metadata for every AirNow reporting area: its location, time zone, agency,
#' and the rules AirNow uses to pick monitors for it. Reporting-area codes
#' are the `area` argument to [get_airnow_observations()],
#' [get_airnow_forecasts()], and [get_airnow_forecast_history()].
#'
#' Reporting areas are occasionally added, renamed, or retired between
#' package releases, so a live response can name an area missing from this
#' table. Functions that join against it warn when that happens and leave
#' the geography columns `NA`.
#'
#' @format A tibble with 1,036 rows and 14 columns:
#' \describe{
#'   \item{reporting_area}{Area name. Not unique: 26 names appear in more
#'     than one state (e.g. Aberdeen, SD and Aberdeen, WA).}
#'   \item{state_code}{Two-letter state or province code}
#'   \item{country_code}{Two-letter country code (US, CA, MX)}
#'   \item{latitude, longitude}{Representative point, decimal degrees}
#'   \item{gmt_offset}{Standard-time offset from UTC, in hours. AirNow's source
#'     rounds fractional offsets to whole hours; known half- and quarter-hour
#'     zones are corrected in this dataset.}
#'   \item{observes_dst}{Whether the area observes daylight saving time}
#'   \item{tz_standard, tz_daylight}{Time zone abbreviations as AirNow
#'     records them. Some are non-standard (Anchorage: `AKT`/`ADT`).}
#'   \item{reporting_area_code}{Unique code, e.g. `"ca064"`}
#'   \item{agency}{Agency responsible for the area}
#'   \item{lookup_behavior}{How AirNow picks monitors, e.g.
#'     `"Closest Reading By Pollutant"`}
#'   \item{considered_monitors}{Which monitors are eligible}
#'   \item{lookup_boundary}{Search radius, e.g. `"50 miles"`; `NA` when
#'     AirNow leaves it blank}
#' }
#'
#' @source AirNow reporting area metadata,
#'   <https://files.airnowtech.org/airnow/today/reportingarea_metadata.dat>,
#'   retrieved 2026-09-12. AirNow is a partnership of the U.S. EPA, NOAA,
#'   NPS, tribal, state, and local agencies; the file is published without
#'   access restrictions. One exact duplicate row (Monterrey, `mx002`) was
#'   removed. Rebuild with `data-raw/airnow_areas.R`.
"airnow_areas"


# Package code must use this accessor rather than the bare dataset name so
# the lookup works whether or not the package is attached (lazy-loaded data
# lives in the package environment, not the namespace).
areas_table <- function() {
  airnow::airnow_areas
}
