test_that("get_airnow_forecast_history() validates inputs before any request", { # nolint
  httptest2::without_internet({
    expect_error(
      get_airnow_forecast_history("Napa", "2026-01-13", "2026-01-14"),
      "reporting area code"
    )
    expect_error(
      get_airnow_forecast_history("md008", "2026-01-14", "2026-01-13"),
      "must not be after"
    )
    expect_error(
      get_airnow_forecast_history("md008", "bad", "2026-01-14"),
      "YYYY-MM-DD"
    )
    expect_error(
      get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", range = 0), # nolint
      "positive whole number"
    )
    expect_error(
      get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", range = 1.5), # nolint
      "positive whole number"
    )
    expect_error(
      get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", parameter = "radon"), # nolint
      "must be one of"
    )
    expect_error(
      get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", clean_names = NA), # nolint
      "clean_names"
    )
  })
})

test_that("get_airnow_forecast_history() returns the forecast contract", {
  httptest2::with_mock_dir("forecast_history", {
    all_rows <- get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14") # nolint
    narrowed <- get_airnow_forecast_history(
      "md008", as.Date("2026-01-13"), as.Date("2026-01-13"),
      range = 1, parameter = "pm2.5"
    )
  })
  expect_s3_class(all_rows, "tbl_df")
  expect_named(all_rows, c(
    "date_issue", "date_valid", "reporting_area", "reporting_area_code",
    "state_code", "latitude", "longitude", "parameter", "aqi",
    "category_number", "category_name", "action_day", "discussion",
    "forecast_agency"
  ))
  expect_true(nrow(all_rows) > nrow(narrowed))
  expect_true(all(all_rows$date_valid >= as.Date("2026-01-13")))
  expect_true(all(all_rows$date_valid <= as.Date("2026-01-14")))

  expect_equal(nrow(narrowed), 1)
  expect_equal(as.character(narrowed$parameter), "pm2.5")
  expect_equal(narrowed$date_valid, as.Date("2026-01-13"))
  expect_equal(narrowed$date_issue, as.Date("2026-01-12"))
})

test_that("get_airnow_forecast_history() warns about future dates", {
  tomorrow <- Sys.Date() + 1
  httptest2::without_internet({
    expect_warning(
      try(get_airnow_forecast_history("md008", tomorrow, tomorrow), silent = TRUE), # nolint
      "future"
    )
  })
})
