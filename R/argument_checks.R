check_zip <- function(x, arg_name = "zip") {
  if (is.na(x) || !grepl("^\\d{5}$", x)) {
    cli::cli_abort("{.arg {arg_name}} must be a 5-digit numeric string")
  }
  x
}

check_latitude <- function(x, arg_name = "latitude") {
  if (!is_scalar_double(x) || abs(x) > 90 || is.na(x)) {
    cli::cli_abort("{.arg {arg_name}} must be a single value between -90 and 90, inclusive") # nolint
  }
  x
}

check_longitude <- function(x, arg_name = "longitude") {
  if (!is_scalar_double(x) || abs(x) > 180 || is.na(x)) { # nolint
    cli::cli_abort("{.arg {arg_name}} must be a single value between -180 and 80, inclusive") # nolint
  }
  x
}

check_location <- function(zip = NULL,
                           latitude = NULL,
                           longitude = NULL) {
  if (!is.null(zip)) {
    location_type <- "zipCode"
    zip <- as.character(zip)
    zip <- check_zip(zip)

    if (!is.null(latitude)) {
      cli::cli_warn("Ignoring {.arg latitude} when {.arg zip} is provided") # nolint
      latitude <- NULL
    }

    if (!is.null(longitude)) {
      cli::cli_warn("Ignoring {.arg longitude} when {.arg zip} is provided") # nolint
      longitude <- NULL
    }
  } else if (!is.null(latitude) && !is.null(longitude)) {
    location_type <- "latLong"
    latitude <- check_latitude(latitude)
    longitude <- check_longitude(longitude)
  } else {
    cli::cli_abort("Either {.arg zip} or {.arg latitude} and {.arg longitude} must be specified") # nolint
  }

  list(
    type = location_type,
    zip = zip,
    latitude = latitude,
    longitude = longitude
  )
}

check_distance <- function(distance) {
  if (!is.null(distance)) {
    if (!is_double(distance, n = 1, finite = TRUE)) {
      cli::cli_abort("{.arg distance} must be a single, non-negative number")
    } else if (distance < 0) {
      cli::cli_abort("{.arg distance} must be at least 0")
    }
  }
  distance
}

check_date <- function(x, arg_name = "date") {
  if (!is.null(x) && !grepl("^\\d{4}-\\d{2}-\\d{2}$", x)) {
    cli::cli_abort("{.arg {arg_name}} must be a string with format YYYY-MM-DD")
  }
  x
}

check_bounding_box <- function(box) {
  if (!is_double(box, n = 4, finite = TRUE) ||
    (!all(abs(box) <= 180)) ||
    (!all(abs(c(box[1], box[3])) <= 90))) {
    cli::cli_abort("{.arg box} must be a 4-element numeric vector with format {.emph (lat1, lon1, lat2, lon2)}, where {.emph lat1} and {.emph lat2} are between -90 and 90, inclusive, and {.emph lon1} and {.emph lon2} are between -180 and 180, inclusive.") # nolint
  }
  box
}
