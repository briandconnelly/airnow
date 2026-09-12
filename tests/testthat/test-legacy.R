legacy_observation_input <- function() {
  tibble::tibble(
    date_observed = as.Date("2026-09-09"), hour_observed = 18L,
    local_time_zone = "PDT",
    utc_datetime = as.POSIXct("2026-09-10 01:00:00", tz = "UTC"),
    reporting_area = "NW Coastal LA", reporting_area_code = "ca132",
    reporting_area_agency = "South Coast AQMD", state_code = "CA",
    latitude = 34.0505, longitude = -118.4566, site_id = "840060374010",
    site_name = "North Holywood", reporting_agency = "South Coast AQMD",
    parameter = factor(c("ozone", "pm2.5"), levels = parameter_levels),
    aqi = c(34L, 74L), category_number = c(1L, 2L),
    category_name = factor(c("Good", "Moderate"), levels = category_levels, ordered = TRUE), # nolint
    lookup_behavior = "Closest Reading By Pollutant",
    considered_monitors = "All", lookup_boundary = "50 Miles",
    source = factor("ziplatlong", levels = c("ziplatlong", "racode"))
  )
}

test_that("observations_to_legacy() reproduces the old columns and vocabulary", { # nolint
  result <- observations_to_legacy(legacy_observation_input())
  expect_named(result, c(
    "DateObserved", "HourObserved", "LocalTimeZone", "ReportingArea",
    "StateCode", "Latitude", "Longitude", "ParameterName", "AQI",
    "Category.Number", "Category.Name"
  ))
  expect_equal(result$HourObserved, c(17L, 17L))
  expect_equal(result$DateObserved, as.Date(c("2026-09-09", "2026-09-09")))
  expect_equal(as.character(result$ParameterName), c("O3", "PM2.5"))
  expect_s3_class(result$ParameterName, "factor")
  expect_s3_class(result$LocalTimeZone, "factor")
  expect_s3_class(result$ReportingArea, "factor")
  expect_s3_class(result$StateCode, "factor")
  expect_false(is.ordered(result$Category.Name))
  expect_equal(levels(result$Category.Name), category_levels)
  expect_equal(result$AQI, c(34L, 74L))
  expect_equal(result$Category.Number, c(1L, 2L))
})

test_that("observations_to_legacy() wraps midnight to 23:00 the previous day", { # nolint
  # ASSUMPTION pending the midnight probe (spec section 5.1): a "00:00"
  # label describes 23:00-23:59 of the previous calendar day.
  x <- legacy_observation_input()[1, ]
  x$hour_observed <- 0L
  x$date_observed <- as.Date("2026-09-10")
  result <- observations_to_legacy(x)
  expect_equal(result$HourObserved, 23L)
  expect_equal(result$DateObserved, as.Date("2026-09-09"))
})

test_that("observations_to_legacy() is NA-safe on the hour", {
  x <- legacy_observation_input()[1, ]
  x$hour_observed <- NA_integer_
  result <- observations_to_legacy(x)
  expect_true(is.na(result$HourObserved))
  expect_equal(result$DateObserved, as.Date("2026-09-09"))
})

test_that("observations_to_legacy() handles zero rows", {
  x <- legacy_observation_input()[0, ]
  result <- observations_to_legacy(x)
  expect_equal(nrow(result), 0)
  expect_equal(ncol(result), 11)
})

test_that("forecasts_to_legacy() reproduces the old columns", {
  x <- tibble::tibble(
    date_issue = as.Date("2026-09-08"), date_valid = as.Date("2026-09-09"),
    reporting_area = "NW Coastal LA", reporting_area_code = "ca132",
    state_code = "CA", latitude = 34.0505, longitude = -118.4566,
    parameter = factor(c("ozone", "pm2.5"), levels = parameter_levels),
    aqi = c(34L, 53L), category_number = c(1L, 2L),
    category_name = factor(c("Good", "Moderate"), levels = category_levels, ordered = TRUE), # nolint
    action_day = FALSE, discussion = "", forecast_agency = "South Coast AQMD"
  )
  result <- forecasts_to_legacy(x)
  expect_named(result, c(
    "DateIssue", "DateForecast", "ReportingArea", "StateCode", "Latitude",
    "Longitude", "ParameterName", "AQI", "ActionDay", "Discussion",
    "Category.Number", "Category.Name"
  ))
  expect_equal(result$DateForecast, as.Date(c("2026-09-09", "2026-09-09")))
  expect_equal(as.character(result$ParameterName), c("O3", "PM2.5"))
  expect_false(is.ordered(result$Category.Name))
  expect_equal(result$ActionDay, c(FALSE, FALSE))
  expect_equal(nrow(forecasts_to_legacy(x[0, ])), 0)
})
