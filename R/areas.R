# Session-level state. `area_codes` memoises location -> reporting area code
# so a loop over the same location costs one request, not one per call.
the <- new.env(parent = emptyenv())
the$area_codes <- list()


#' Rows of `airnow_areas` with the given reporting-area name
#' @param name A single area name as the API returns it
#' @return A tibble with 0, 1, or several rows
#' @noRd
lookup_areas_by_name <- function(name) {
  areas <- areas_table()
  areas[!is.na(areas$reporting_area) & areas$reporting_area == name, , drop = FALSE] # nolint
}


#' Great-circle distance in kilometres
#' @noRd
haversine_km <- function(lat1, lon1, lat2, lon2) {
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 +
    cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  2 * 6371 * asin(pmin(1, sqrt(a)))
}


#' The candidate row closest to a point
#' @param latitude,longitude Query point in decimal degrees
#' @param candidates A subset of `airnow_areas` with at least one row
#' @return A one-row tibble
#' @noRd
nearest_area <- function(latitude, longitude, candidates) {
  d <- haversine_km(latitude, longitude, candidates$latitude, candidates$longitude) # nolint
  candidates[which.min(d), , drop = FALSE]
}


#' Resolve a zip code or coordinate pair to a reporting-area code
#'
#' Uses `/forecast/current/`, which returns `reportingAreaCode` for both
#' input types (spec section 2.3). Results are memoised in `the$area_codes`
#' for the session.
#'
#' @inheritParams get_airnow_observations
#' @return A single area code such as `"ca132"`
#' @noRd
resolve_area_code <- function(zip = NULL,
                              latitude = NULL,
                              longitude = NULL,
                              api_key = get_airnow_key()) {
  location <- check_location(zip, latitude, longitude)

  memo_key <- if (location$type == "zipCode") {
    paste0("zip:", location$zip)
  } else {
    paste0("latlong:", location$latitude, ",", location$longitude)
  }

  cached <- the$area_codes[[memo_key]]
  if (!is.null(cached)) {
    return(cached)
  }

  result <- req_airnow() |>
    httr2::req_url_path_append("forecast", "current") |>
    httr2::req_url_query(
      zipCode = location$zip,
      latitude = location$latitude,
      longitude = location$longitude,
      format = "application/json",
      api_key = api_key
    ) |>
    perform_airnow()

  if (nrow(result) == 0 || !("reportingAreaCode" %in% names(result))) {
    cli::cli_abort("No AirNow reporting area was found for the given location") # nolint
  }

  code <- as.character(result$reportingAreaCode[[1]])
  the$area_codes[[memo_key]] <- code
  code
}


# Columns added by join_areas_by_name(), with their NA of the right type
area_join_defaults <- list(
  reportingAreaCode = NA_character_,
  stateCode = NA_character_,
  latitude = NA_real_,
  longitude = NA_real_,
  reportingAreaAgency = NA_character_
)


#' Add reporting-area geography to rows that only carry an area name
#'
#' The `/ziplatLong` service returns `reportingAreaName` but no code or
#' state, and 26 names appear in more than one state. Unambiguous names are
#' joined offline. Ambiguous names are resolved offline by nearest neighbour
#' when the query was a coordinate pair, and via one memoised API call when
#' the query was a zip code. Names missing from the table warn and stay NA.
#'
#' @param x A tibble with a character column `reportingAreaName`
#' @param zip,latitude,longitude The original query (one form or the other)
#' @param api_key API key, only used for the ambiguous-zip case
#' @return `x` with the five columns in `area_join_defaults` added
#' @noRd
join_areas_by_name <- function(x,
                               zip = NULL,
                               latitude = NULL,
                               longitude = NULL,
                               api_key = get_airnow_key()) {
  n <- nrow(x)
  for (col in names(area_join_defaults)) {
    x[[col]] <- rep(area_join_defaults[[col]], n)
  }
  if (n == 0) {
    return(x)
  }

  misses <- character(0)
  for (name in unique(x$reportingAreaName)) {
    candidates <- lookup_areas_by_name(name)
    row <- NULL

    if (nrow(candidates) == 1) {
      row <- candidates
    } else if (nrow(candidates) > 1) {
      if (!is.null(zip)) {
        code <- resolve_area_code(zip = zip, api_key = api_key)
        row <- candidates[candidates$reporting_area_code == code, , drop = FALSE] # nolint
      } else {
        row <- nearest_area(latitude, longitude, candidates)
      }
    }

    if (is.null(row) || nrow(row) != 1) {
      misses <- c(misses, name)
      next
    }

    sel <- !is.na(x$reportingAreaName) & x$reportingAreaName == name
    x$reportingAreaCode[sel] <- row$reporting_area_code
    x$stateCode[sel] <- row$state_code
    x$latitude[sel] <- row$latitude
    x$longitude[sel] <- row$longitude
    x$reportingAreaAgency[sel] <- row$agency
  }

  if (length(misses) > 0) {
    cli::cli_warn(c(
      "Reporting area{?s} {.val {misses}} not found in {.field airnow_areas}; geography columns will be {.val NA}", # nolint
      "i" = "AirNow adds, renames, and retires areas; the bundled table may be stale." # nolint
    ))
  }
  x
}


#' Add coordinates (and a missing state code) to rows that carry an area code
#'
#' @param x A tibble with a character column `reportingAreaCode`
#' @return `x` with `latitude`, `longitude`, and `stateCode` filled
#' @noRd
join_areas_by_code <- function(x) {
  areas <- areas_table()
  idx <- match(x$reportingAreaCode, areas$reporting_area_code)

  unknown <- unique(x$reportingAreaCode[is.na(idx) & !is.na(x$reportingAreaCode)]) # nolint
  if (length(unknown) > 0) {
    cli::cli_warn("Reporting area code{?s} {.val {unknown}} not found in {.field airnow_areas}; geography columns will be {.val NA}") # nolint
  }

  x$latitude <- areas$latitude[idx]
  x$longitude <- areas$longitude[idx]

  if (!("stateCode" %in% names(x))) {
    x$stateCode <- rep(NA_character_, nrow(x))
  }
  fill <- is.na(x$stateCode)
  x$stateCode[fill] <- areas$state_code[idx][fill]
  x
}
