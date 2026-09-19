forecast_clean_names <- c(
  "date_issue", "date_valid", "reporting_area", "reporting_area_code",
  "state_code", "latitude", "longitude", "parameter", "aqi",
  "category_number", "category_name", "action_day", "discussion",
  "forecast_agency"
)
forecast_raw_names <- c(
  "dateIssue", "dateValid", "reportingArea", "reportingAreaCode",
  "stateCode", "latitude", "longitude", "parameterName", "aqi",
  "categoryNumber", "categoryName", "actionDay", "discussion",
  "forecastAgency"
)

test_that("get_airnow_forecasts() validates inputs before any request", {
  httptest2::without_internet({
    expect_error(get_airnow_forecasts(), "must be specified")
    expect_error(get_airnow_forecasts(zip = "1234"), "5-digit")
    expect_error(
      get_airnow_forecasts(latitude = 91, longitude = 0),
      "between -90 and 90"
    )
    expect_error(get_airnow_forecasts(area = "Napa"), "reporting area code")
    expect_error(
      get_airnow_forecasts(zip = "90210", clean_names = NA),
      "clean_names"
    )
    expect_error(
      get_airnow_forecasts(zip = "90210", clean_names = "yes"),
      "clean_names"
    )
  })
})

test_that("finish_forecast() normalizes a raw payload", {
  raw <- tibble::tibble(
    dateIssue = "2026-09-08", dateValid = "2026-09-09",
    reportingArea = "NW Coastal LA", reportingAreaCode = "ca132",
    stateCode = "CA", parameterName = c("PM2.5", "OZONE"), aqi = c(53L, 34L),
    forecastAgency = "South Coast AQMD", categoryNumber = c(2L, 1L),
    categoryName = c("Moderate", "Good"), actionDay = FALSE, discussion = ""
  )
  result <- finish_forecast(raw, clean_names = TRUE)
  expect_named(result, forecast_clean_names)
  expect_s3_class(result$date_issue, "Date")
  expect_s3_class(result$date_valid, "Date")
  expect_equal(as.character(result$parameter), c("pm2.5", "ozone"))
  expect_true(is.ordered(result$category_name))
  expect_equal(as.character(result$category_name), c("Moderate", "Good"))
  expect_type(result$aqi, "integer")
  expect_type(result$category_number, "integer")
  expect_type(result$action_day, "logical")
  expect_false(anyNA(result$latitude))

  raw_out <- finish_forecast(raw, clean_names = FALSE)
  expect_named(raw_out, forecast_raw_names)
})

test_that("finish_forecast() returns the full contract for zero rows", {
  result <- finish_forecast(tibble::tibble(), clean_names = TRUE)
  expect_named(result, forecast_clean_names)
  expect_equal(nrow(result), 0)
  expect_s3_class(result$date_valid, "Date")
})

test_that("finish_forecast() fills forecastAgency when the service omits it", {
  raw <- tibble::tibble(
    dateIssue = "2026-01-12", dateValid = "2026-01-13",
    reportingArea = "Northeast Maryland", reportingAreaCode = "md008",
    stateCode = "MD", parameterName = "PM2.5", aqi = 44L,
    categoryNumber = 1L, categoryName = "Good", actionDay = FALSE,
    discussion = "x"
  )
  result <- finish_forecast(raw, clean_names = TRUE)
  expect_true(is.na(result$forecast_agency))
  expect_named(result, forecast_clean_names)
})

test_that("get_airnow_forecasts() returns the contract for each location type", { # nolint
  httptest2::with_mock_dir("forecasts", {
    by_zip <- get_airnow_forecasts(zip = "90210")
    by_latlong <- get_airnow_forecasts(latitude = 38.3191, longitude = -122.2998) # nolint
    by_area <- get_airnow_forecasts(area = "ca132")
    raw <- get_airnow_forecasts(zip = "90210", clean_names = FALSE)
  })
  for (result in list(by_zip, by_latlong, by_area)) {
    expect_s3_class(result, "tbl_df")
    expect_named(result, forecast_clean_names)
    expect_true(nrow(result) > 0)
    expect_false(anyNA(result$latitude))
  }
  expect_equal(unique(as.character(by_zip$reporting_area_code)), "ca132")
  expect_equal(unique(as.character(by_latlong$reporting_area_code)), "ca064")
  expect_named(raw, forecast_raw_names)
})

test_that("get_airnow_forecasts() returns zero rows when no area serves the point", { # nolint
  httptest2::with_mock_dir("forecasts_nodata", {
    result <- get_airnow_forecasts(latitude = 39.5, longitude = -116.9)
  })
  expect_equal(nrow(result), 0)
  expect_named(result, forecast_clean_names)
})
