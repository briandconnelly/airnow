obs_clean_names <- c(
  "date_observed", "hour_observed", "local_time_zone", "utc_datetime",
  "reporting_area", "reporting_area_code", "reporting_area_agency",
  "state_code", "latitude", "longitude", "site_id", "site_name",
  "reporting_agency", "parameter", "aqi", "category_number",
  "category_name", "lookup_behavior", "considered_monitors",
  "lookup_boundary", "source"
)
obs_raw_names <- c(
  "dateObserved", "hourObserved", "localTimeZone", "utcDatetime",
  "reportingAreaName", "reportingAreaCode", "reportingAreaAgency",
  "stateCode", "latitude", "longitude", "siteID", "siteName",
  "reportingAgency", "parameterName", "nowcastAQI", "categoryNumber",
  "aqiCategoryName", "lookupBehavior", "consideredMonitors",
  "lookupBoundary", "source"
)

ziplatlong_payload <- function() {
  tibble::tibble(
    dateObserved = "2026-09-09", hourObserved = "18:00",
    localTimeZone = "PDT", reportingAreaName = "NW Coastal LA",
    siteID = c("840060374010", "060370113"),
    siteName = c("North Holywood", "West Los Angeles"),
    parameterName = c("PM2.5", "OZONE"), nowcastAQI = c(74L, 34L),
    aqiCategoryName = c("Moderate", "Good"),
    reportingAgency = "South Coast AQMD",
    lookupBehavior = "Closest Reading By Pollutant",
    consideredMonitors = "All", lookupBoundary = "50 Miles"
  )
}

racode_payload <- function() {
  tibble::tibble(
    dateObserved = "2026-09-09", hourObserved = "17:00",
    localTimeZone = "PDT", reportingAreaName = "Napa",
    reportingAreaAgency = "Bay Area Air District",
    reportingAreaCode = "ca064", aqiCategoryName = c("Good", "Good"),
    parameterName = c("OZONE", "PM2.5"), nowcastAQI = c(45L, 20L)
  )
}

test_that("get_airnow_observations() validates inputs before any request", { # nolint
  httptest2::without_internet({
    expect_error(get_airnow_observations(), "must be specified")
    expect_error(get_airnow_observations(zip = "1234"), "5-digit")
    expect_error(
      get_airnow_observations(latitude = 91, longitude = 0),
      "between -90 and 90"
    )
    expect_error(get_airnow_observations(area = "Napa"), "reporting area code")
    expect_error(
      get_airnow_observations(zip = "90210", clean_names = NA),
      "clean_names"
    )
  })
})

test_that("finish_observations() normalizes a ziplatLong payload", {
  result <- finish_observations(
    ziplatlong_payload(), source = "ziplatlong", zip = "90210"
  )
  expect_named(result, obs_raw_names)
  expect_s3_class(result$dateObserved, "Date")
  expect_equal(result$hourObserved, c(18L, 18L))
  expect_equal(
    result$utcDatetime,
    rep(as.POSIXct("2026-09-10 01:00:00", tz = "UTC"), 2)
  )
  expect_equal(result$reportingAreaCode, c("ca132", "ca132"))
  expect_equal(result$stateCode, c("CA", "CA"))
  expect_false(anyNA(result$latitude))
  expect_equal(result$reportingAreaAgency, rep("South Coast AQMD", 2))
  expect_equal(as.character(result$parameterName), c("pm2.5", "ozone"))
  expect_equal(result$nowcastAQI, c(74L, 34L))
  expect_equal(result$categoryNumber, c(2L, 1L))
  expect_true(is.ordered(result$aqiCategoryName))
  expect_equal(as.character(result$source), c("ziplatlong", "ziplatlong"))
  expect_equal(levels(result$source), c("ziplatlong", "racode"))
})

test_that("finish_observations() normalizes a racode payload with NA site columns", { # nolint
  result <- finish_observations(racode_payload(), source = "racode")
  expect_named(result, obs_raw_names)
  expect_true(all(is.na(result$siteID)))
  expect_true(all(is.na(result$siteName)))
  expect_true(all(is.na(result$lookupBehavior)))
  expect_equal(result$stateCode, c("CA", "CA"))
  expect_false(anyNA(result$latitude))
  expect_equal(result$hourObserved, c(17L, 17L))
  expect_equal(
    result$utcDatetime,
    rep(as.POSIXct("2026-09-10 00:00:00", tz = "UTC"), 2)
  )
  expect_equal(as.character(result$source), c("racode", "racode"))
})

test_that("finish_observations() keeps the API's midnight label unshifted", {
  x <- ziplatlong_payload()[1, ]
  x$dateObserved <- "2026-09-10"
  x$hourObserved <- "00:00"
  result <- finish_observations(x, source = "ziplatlong", zip = "90210")
  expect_equal(result$hourObserved, 0L)
  expect_equal(result$dateObserved, as.Date("2026-09-10"))
  expect_equal(result$utcDatetime, as.POSIXct("2026-09-10 07:00:00", tz = "UTC")) # nolint
})

test_that("finish_observations() warns on a join miss and keeps the row", {
  x <- ziplatlong_payload()[1, ]
  x$reportingAreaName <- "Atlantis"
  expect_warning(
    result <- finish_observations(x, source = "ziplatlong", zip = "90210"),
    "Atlantis"
  )
  expect_equal(nrow(result), 1)
  expect_true(is.na(result$reportingAreaCode))
  expect_true(is.na(result$latitude))
  expect_true(is.na(result$utcDatetime))
  expect_equal(result$nowcastAQI, 74L)
})

test_that("finish_observations() warns on an unmatched time zone", {
  x <- ziplatlong_payload()[1, ]
  x$localTimeZone <- "XYZ"
  expect_warning(
    result <- finish_observations(x, source = "ziplatlong", zip = "90210"),
    "XYZ"
  )
  expect_true(is.na(result$utcDatetime))
  expect_equal(result$hourObserved, 18L)
})

test_that("finish_observations() returns the full contract for zero rows", {
  result <- finish_observations(tibble::tibble(), source = "racode")
  expect_named(result, obs_raw_names)
  expect_equal(nrow(result), 0)
  expect_s3_class(result$utcDatetime, "POSIXct")
  expect_s3_class(result$source, "factor")
})

test_that("get_airnow_observations() returns the contract for each location type", { # nolint
  local_area_code_cache()
  httptest2::with_mock_dir("observations", {
    by_zip <- get_airnow_observations(zip = "90210")
    by_latlong <- get_airnow_observations(latitude = 38.3191, longitude = -122.2998) # nolint
    by_area <- get_airnow_observations(area = "ca064")
    raw <- get_airnow_observations(zip = "90210", clean_names = FALSE)
  })
  for (result in list(by_zip, by_latlong, by_area)) {
    expect_s3_class(result, "tbl_df")
    expect_named(result, obs_clean_names)
    expect_true(nrow(result) > 0)
    expect_false(anyNA(result$reporting_area_code))
    expect_false(anyNA(result$utc_datetime))
  }
  expect_equal(unique(as.character(by_zip$source)), "ziplatlong")
  expect_equal(unique(as.character(by_area$source)), "racode")
  expect_true(all(is.na(by_area$site_id)))
  expect_false(anyNA(by_zip$site_id))
  expect_named(raw, obs_raw_names)
})

test_that("get_airnow_observations() returns zero rows when nothing is nearby", { # nolint
  httptest2::with_mock_dir("observations_nodata", {
    result <- get_airnow_observations(latitude = 39.5, longitude = -116.9)
  })
  expect_equal(nrow(result), 0)
  expect_named(result, obs_clean_names)
})
