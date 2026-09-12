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
        (!all(abs(c(box[2], box[4])) <= 90)) ||
        (box[1] > box[3]) ||
        (box[2] > box[4])) {
    cli::cli_abort("{.arg box} must be a 4-element numeric vector with format {.emph (xmin, ymin, xmax, ymax)}, where {.emph lat1} and {.emph lat2} are between -90 and 90, inclusive, and {.emph lon1} and {.emph lon2} are between -180 and 180, inclusive.") # nolint
    # TODO: make sure xmin <= xmax and ymin <= ymax
  }
  box
}

check_aqi <- function(x, arg_name = "aqi") {
  # A bare logical NA (e.g. `NA`) is a legitimate missing value
  if (is.logical(x) && length(x) > 0 && all(is.na(x))) {
    x <- as.integer(x)
  }

  if (length(x) == 0 || !is_integerish(x)) {
    cli::cli_abort("{.arg {arg_name}} must be a vector of whole numbers")
  }

  x <- as.integer(x)
  negative <- !is.na(x) & x < 0

  if (any(negative & x == -1)) {
    cli::cli_warn("{.arg {arg_name}} contains -1, the AirNow sentinel for a categorical forecast; returning {.val NA} for those values") # nolint
  }
  if (any(negative & x != -1)) {
    cli::cli_warn("{.arg {arg_name}} contains negative values; returning {.val NA} for those values") # nolint
  }
  x[negative] <- NA_integer_

  x
}

check_clean_names <- function(x) {
  if (!is_logical(x, n = 1) || is.na(x)) {
    cli::cli_abort("{.arg clean_names} must be either `TRUE` or `FALSE`")
  }
  x
}

check_area_code <- function(x, arg_name = "area") {
  if (!is_string(x) || is.na(x)) {
    cli::cli_abort("{.arg {arg_name}} must be a single reporting area code such as {.val ca064}") # nolint
  }
  x <- tolower(x)
  if (!grepl("^[a-z]{2}[0-9]{3}$", x)) {
    cli::cli_abort("{.arg {arg_name}} must be a reporting area code such as {.val ca064}; see {.code airnow_areas} or {.fn get_airnow_reporting_area}") # nolint
  }
  x
}

check_area_or_location <- function(zip = NULL,
                                   latitude = NULL,
                                   longitude = NULL,
                                   area = NULL) {
  if (!is.null(area)) {
    if (!is.null(zip) || !is.null(latitude) || !is.null(longitude)) {
      cli::cli_warn("Ignoring {.arg zip}, {.arg latitude}, and {.arg longitude} because {.arg area} was provided") # nolint
    }
    return(list(
      type = "area", zip = NULL, latitude = NULL, longitude = NULL,
      area = check_area_code(area)
    ))
  }
  location <- check_location(zip, latitude, longitude)
  location$area <- NULL
  location
}
