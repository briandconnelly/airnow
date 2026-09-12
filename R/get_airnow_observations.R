# Contract for observation tibbles (raw API names), the union of what the
# ziplatLong and racode services return plus derived and joined columns.
observation_columns <- list(
  dateObserved = as.Date(NA),
  hourObserved = NA_integer_,
  localTimeZone = NA_character_,
  utcDatetime = as.POSIXct(NA, tz = "UTC"),
  reportingAreaName = NA_character_,
  reportingAreaCode = NA_character_,
  reportingAreaAgency = NA_character_,
  stateCode = NA_character_,
  latitude = NA_real_,
  longitude = NA_real_,
  siteID = NA_character_,
  siteName = NA_character_,
  reportingAgency = NA_character_,
  parameterName = NA_character_,
  nowcastAQI = NA_integer_,
  categoryNumber = NA_integer_,
  aqiCategoryName = NA_character_,
  lookupBehavior = NA_character_,
  consideredMonitors = NA_character_,
  lookupBoundary = NA_character_,
  source = NA_character_
)


#' Normalize an observation payload from either observation service
#'
#' @param x Tibble from [perform_airnow()], possibly 0x0
#' @param source `"ziplatlong"` or `"racode"`
#' @param zip,latitude,longitude The original query, needed only to resolve
#'   ambiguous area names on the ziplatlong path
#' @param api_key API key, needed only for the ambiguous-zip case
#' @return A tibble following `observation_columns` (raw names)
#' @noRd
finish_observations <- function(x,
                                source,
                                zip = NULL,
                                latitude = NULL,
                                longitude = NULL,
                                api_key = get_airnow_key()) {
  if (nrow(x) > 0) {
    if (source == "ziplatlong") {
      x <- join_areas_by_name(x, zip, latitude, longitude, api_key)
    } else {
      x <- join_areas_by_code(x)
    }
    x$dateObserved <- as.Date(trimws(x$dateObserved))
    x$hourObserved <- hour_label_to_integer(x$hourObserved)
    x$parameterName <- to_parameter_factor(x$parameterName)
    x$aqiCategoryName <- to_category_factor(x$aqiCategoryName)
    x$categoryNumber <- as.integer(x$aqiCategoryName)
    x$nowcastAQI <- as.integer(x$nowcastAQI)
    x$utcDatetime <- derive_utc_datetime(
      x$dateObserved, x$hourObserved, x$localTimeZone, x$reportingAreaCode
    )
    x$source <- rep(source, nrow(x))
  }

  x <- add_missing_columns(x, observation_columns)
  if (nrow(x) == 0) {
    x$parameterName <- to_parameter_factor(character(0))
    x$aqiCategoryName <- to_category_factor(character(0))
  }
  x$source <- factor(x$source, levels = c("ziplatlong", "racode"))
  x
}


#' Get current air quality observations
#'
#' `get_airnow_observations()` retrieves the most recent hourly readings for
#' a location. Locate it by ZIP code or latitude/longitude, or give a
#' reporting area code. The two forms use different AirNow services with
#' different methodologies:
#'
#' * By ZIP code or coordinates, AirNow returns the closest reading for each
#'   pollutant within the reporting area's search radius, and names the site
#'   it came from (`site_id`, `site_name`).
#' * By `area`, AirNow returns the area's official value for each pollutant
#'   and omits the site columns, which are `NA`.
#'
#' The `source` column records which service produced each row.
#'
#' @section Requests made:
#' One request per call, plus one extra request (cached for the session)
#' when a ZIP code's reporting area shares its name with an area in another
#' state. There are 26 such names; see [airnow_areas]. All requests count
#' against AirNow's 500-per-hour limit.
#'
#' @section Time columns:
#' `hour_observed` uses AirNow's convention of labelling an hour by its
#' **end**: `18` means the period 17:00-17:59. `date_observed` and
#' `hour_observed` are local to each reporting area, and `local_time_zone`
#' is an abbreviation R cannot interpret. `utc_datetime` is derived from the
#' reporting area's metadata in [airnow_areas] and is the column to use when
#' comparing areas or joining with [get_airnow_monitors()]. It is `NA` when
#' the area or its time zone cannot be matched.
#'
#' @inheritParams get_airnow_forecasts
#'
#' @return A tibble with one row per pollutant. `parameter` is a factor with
#'   levels `ozone`, `pm2.5`, `pm10`, `co`, `no2`, `so2`; `category_name` is
#'   an ordered factor; `aqi` is the NowCast AQI.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_observations(zip = "90210")
#' get_airnow_observations(latitude = 38.3191, longitude = -122.2998)
#' get_airnow_observations(area = "ca064")
#' }
get_airnow_observations <- function(zip = NULL,
                                    latitude = NULL,
                                    longitude = NULL,
                                    area = NULL,
                                    clean_names = TRUE,
                                    api_key = get_airnow_key()) {
  query <- check_area_or_location(zip, latitude, longitude, area)
  check_clean_names(clean_names)

  if (query$type == "area") {
    source <- "racode"
    req <- req_airnow() |>
      httr2::req_url_path_append("observation", "current", "racode") |>
      httr2::req_url_query(
        reportingAreaCode = query$area,
        format = "application/json",
        api_key = api_key
      )
  } else {
    source <- "ziplatlong"
    req <- req_airnow() |>
      httr2::req_url_path_append("observation", "current", "ziplatLong") |>
      httr2::req_url_query(
        zipCode = query$zip,
        latitude = query$latitude,
        longitude = query$longitude,
        format = "application/json",
        api_key = api_key
      )
  }

  result <- perform_airnow(req)
  result <- finish_observations(
    result, source,
    zip = query$zip, latitude = query$latitude, longitude = query$longitude,
    api_key = api_key
  )

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}
