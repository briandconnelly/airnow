# Canonical pollutant names. The API spells ozone three ways (OZONE, Ozone,
# O3) across services; everything else is stable.
parameter_levels <- c("ozone", "pm2.5", "pm10", "co", "no2", "so2")


#' Build a factor, warning about values that would silently become NA
#'
#' @param x Character vector
#' @param levels Allowed levels
#' @param what Noun for the warning message, e.g. "parameter"
#' @param ordered Passed to [factor()]
#' @return A factor
#' @noRd
factor_with_warning <- function(x, levels, what, ordered = FALSE) {
  x <- as.character(x)
  unmatched <- unique(x[!is.na(x) & !(x %in% levels)])
  if (length(unmatched) > 0) {
    cli::cli_warn(c(
      "Unrecognised {what} value{?s}: {.val {unmatched}}",
      "i" = "These will become {.val NA}. Please report this at {.url https://github.com/briandconnelly/airnow/issues}" # nolint
    ))
  }
  factor(x, levels = levels, ordered = ordered)
}


#' Convert API pollutant names to the package's canonical factor
#' @param x Character vector such as `c("OZONE", "PM2.5")`
#' @return An unordered factor on [parameter_levels]
#' @noRd
to_parameter_factor <- function(x) {
  orig_x <- as.character(x)
  x <- tolower(as.character(x))
  x[!is.na(x) & x == "o3"] <- "ozone"
  # Warn about unmatched, preserving original case
  unmatched <- unique(x[!is.na(x) & !(x %in% parameter_levels)])
  if (length(unmatched) > 0) {
    is_unmatched <- !is.na(x) & !(x %in% parameter_levels)
    # nolint next: object_usage_linter. used below via glue interpolation
    unmatched_orig <- unique(orig_x[is_unmatched])
    cli::cli_warn(c(
      "Unrecognised parameter value{?s}: {.val {unmatched_orig}}",
      "i" = "These will become {.val NA}. Please report this at {.url https://github.com/briandconnelly/airnow/issues}" # nolint
    ))
  }
  factor(x, levels = parameter_levels)
}


#' Convert AQI category names to a factor
#' @param x Character vector such as `c("Good", "Moderate")`
#' @param ordered Whether the factor is ordered (`TRUE` for the new
#'   functions; the legacy shims use `FALSE`)
#' @return A factor on `category_levels`
#' @noRd
to_category_factor <- function(x, ordered = TRUE) {
  factor_with_warning(x, category_levels, "AQI category", ordered = ordered)
}


#' Convert the API's "HH:MM" hour label to an integer hour
#'
#' The 2026 services label an hour by its end: `"18:00"` is the period
#' 17:00-17:59. This function keeps that label (returns 18); it does not
#' shift it. See the compatibility shims for the old start-labelled hour.
#'
#' @param x Character vector such as `c("18:00", "00:00")`
#' @return Integer vector; `NA` where the label is missing or malformed
#' @noRd
hour_label_to_integer <- function(x) {
  x <- as.character(x)
  well_formed <- !is.na(x) & grepl("^[0-9]{2}:[0-9]{2}$", x)
  malformed <- !is.na(x) & !well_formed
  if (any(malformed)) {
    cli::cli_warn("Unexpected {.field hourObserved} value{?s}: {.val {unique(x[malformed])}}; returning {.val NA}") # nolint
  }
  out <- rep(NA_integer_, length(x))
  out[well_formed] <- as.integer(substr(x[well_formed], 1, 2))
  out
}


#' Derive a UTC datetime from AirNow's local date, hour, and zone label
#'
#' Rule (spec section 4.3):
#' 1. Start from the area's standard-time `gmt_offset`.
#' 2. If the area observes DST and `tz_abbr` equals its daylight
#'    abbreviation, add one hour to the offset.
#' 3. If `tz_abbr` equals the standard abbreviation, keep the offset.
#' 4. Otherwise the result is `NA` and a warning names the abbreviation.
#'    Never guess from a "DT" suffix: AirNow's abbreviations are not
#'    standard (Anchorage is recorded as `AKT`/`ADT`).
#'
#' @param date `Date` vector (the API's `dateObserved`)
#' @param hour Integer vector (the API's end-of-period hour label)
#' @param tz_abbr Character vector (the API's `localTimeZone`)
#' @param reporting_area_code Character vector of area codes
#' @return `POSIXct` in UTC, `NA` where any input is missing or the zone
#'   cannot be matched
#' @noRd
derive_utc_datetime <- function(date, hour, tz_abbr, reporting_area_code) {
  areas <- areas_table()
  idx <- match(reporting_area_code, areas$reporting_area_code)

  offset <- areas$gmt_offset[idx]
  is_daylight <- areas$observes_dst[idx] & tz_abbr == areas$tz_daylight[idx]
  is_standard <- tz_abbr == areas$tz_standard[idx]
  is_daylight[is.na(is_daylight)] <- FALSE
  is_standard[is.na(is_standard)] <- FALSE

  unmatched <- !is.na(idx) & !is.na(tz_abbr) & !is_daylight & !is_standard
  if (any(unmatched)) {
    cli::cli_warn("Could not match time zone{?s} {.val {unique(tz_abbr[unmatched])}} to the reporting area metadata; {.field utc_datetime} will be {.val NA}") # nolint
  }

  offset <- offset + ifelse(is_daylight, 1L, 0L)
  known <- !is.na(idx) & !is.na(date) & !is.na(hour) &
    (is_daylight | is_standard)

  local_midnight <- as.POSIXct(date, tz = "UTC")
  out <- local_midnight + hour * 3600 - offset * 3600
  out[!known] <- NA
  attr(out, "tzone") <- "UTC"
  out
}
