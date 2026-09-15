test_that("get_airnow_forecast() catches invalid inputs", {
  httptest2::without_internet({
    # zip is a 5-digit numeric string (or integer)
    expect_error(get_airnow_forecast(zip = NULL))
    expect_error(get_airnow_forecast(zip = NA_character_))
    expect_error(get_airnow_forecast(zip = "98101-1234"))

    # latitude is a scalar number between -90 and 90, inclusive
    expect_error(get_airnow_forecast(zip = NULL, latitude = NA_real_, longitude = 0)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = NULL, longitude = 0)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = 92.0, longitude = 0)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = -92.0, longitude = 0)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = c(45, 45), longitude = 0)) # nolint

    # longitude is a scalar number between -180 and 80, inclusive
    expect_error(get_airnow_forecast(zip = NULL, latitude = NA_real_, longitude = NA_real)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = NULL, longitude = NULL)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = 0, longitude = 181.0)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = 0, longitude = -181.0)) # nolint
    expect_error(get_airnow_forecast(zip = NULL, latitude = 0, longitude = c(93, 15))) # nolint

    # distance is NULL or a non-negative scalar number
    expect_error(get_airnow_forecast(zip = "98101", distance = NA_real_), "distance") # nolint
    expect_error(get_airnow_forecast(zip = "98101", distance = -30), "distance")
    expect_error(get_airnow_forecast(zip = "98101", distance = 1:5), "distance")

    # clean_names is a logical scalar
    expect_error(get_airnow_forecast(zip = "98101", clean_names = NULL), "clean_names") # nolint
    expect_error(get_airnow_forecast(zip = "98101", clean_names = NA), "clean_names") # nolint
    expect_error(get_airnow_forecast(zip = "98101", clean_names = 1), "clean_names") # nolint
    expect_error(get_airnow_forecast(zip = "98101", clean_names = c(TRUE, FALSE)), "clean_names") # nolint

    # area is an additive, mutually exclusive compatibility argument
    expect_error(get_airnow_forecast(area = "not-an-area"), "area")
    expect_error(get_airnow_forecast(zip = "98101", area = "wa004"), "must not be combined") # nolint
    expect_error(get_airnow_forecast(area = "wa004", distance = 25), "distance") # nolint
  })
})


test_that("get_airnow_forecast() produces the expected outputs", {
  httptest2::with_mock_dir("legacy_forecast", {
    lifecycle::expect_deprecated(result <- get_airnow_forecast(zip = "98101")) # nolint
  })

  expect_true(is.data.frame(result))
  expect_true(tibble::is_tibble(result))

  expect_setequal(
    colnames(result),
    c(
      "date_issued",
      "date_forecast",
      "reporting_area",
      "state_code",
      "latitude",
      "longitude",
      "parameter",
      "aqi",
      "action_day",
      "discussion",
      "category_number",
      "category_name"
    )
  )

  httptest2::with_mock_dir("legacy_forecast", {
    lifecycle::expect_deprecated(
      result_noclean <- get_airnow_forecast(zip = "98101", clean_names = FALSE) # nolint
    )
  })

  expect_true(is.data.frame(result_noclean))
  expect_true(tibble::is_tibble(result_noclean))

  expect_setequal(
    colnames(result_noclean),
    c(
      "DateIssue",
      "DateForecast",
      "ReportingArea",
      "StateCode",
      "Latitude",
      "Longitude",
      "ParameterName",
      "AQI",
      "ActionDay",
      "Discussion",
      "Category.Number",
      "Category.Name"
    )
  )
})


test_that("get_airnow_forecast(date = ) narrows to forecasts valid that day", { # nolint
  local_area_code_cache()
  httptest2::with_mock_dir("legacy_forecast_date", {
    lifecycle::expect_deprecated(
      result <- get_airnow_forecast(zip = "90210", date = "2026-01-13")
    )
  })
  expect_true(nrow(result) > 0)
  expect_equal(unique(result$date_forecast), as.Date("2026-01-13"))
  expect_equal(unique(result$date_issued), as.Date("2026-01-12"))
})

test_that("dated legacy forecast uses the offline ZIP crosswalk", {
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) stop("live resolver must not be called")
  )
  httptest2::with_mock_dir("legacy_forecast_date", {
    lifecycle::expect_deprecated(
      result <- get_airnow_forecast(zip = "90210", date = "2026-01-13")
    )
  })
  expect_true(nrow(result) > 0)
})

test_that("explicit area bypasses legacy location resolution", {
  empty_forecast <- function(...) finish_forecast(tibble::tibble(), TRUE)
  testthat::local_mocked_bindings(
    resolve_historical_area_code = function(...) {
      stop("automatic resolver must not be called")
    },
    get_airnow_forecast_history = empty_forecast,
    get_airnow_forecasts = empty_forecast
  )

  lifecycle::expect_deprecated(
    dated <- get_airnow_forecast(area = "wa004", date = "2026-01-13")
  )
  lifecycle::expect_deprecated(
    current <- get_airnow_forecast(area = "wa004")
  )
  expect_equal(nrow(dated), 0)
  expect_equal(nrow(current), 0)
  expect_named(dated, c(
    "date_issued", "date_forecast", "reporting_area", "state_code",
    "latitude", "longitude", "parameter", "aqi", "action_day",
    "discussion", "category_number", "category_name"
  ))
})

test_that("the deprecation warning names the replacement for the call made", { # nolint
  empty_forecast <- function(...) finish_forecast(tibble::tibble(), TRUE)
  testthat::local_mocked_bindings(
    get_airnow_forecast_history = empty_forecast,
    get_airnow_forecasts = empty_forecast
  )
  withr::local_options(lifecycle_verbosity = "warning")

  expect_warning(
    get_airnow_forecast(area = "wa004", date = "2026-01-13"),
    "Please use `get_airnow_forecast_history\\(\\)` instead"
  )
  expect_warning(
    get_airnow_forecast(area = "wa004"),
    "Please use `get_airnow_forecasts\\(\\)` instead"
  )
})

test_that("adding area preserves the legacy positional arguments", {
  expect_identical(
    names(formals(get_airnow_forecast))[1:7],
    c(
      "zip", "latitude", "longitude", "distance", "date", "clean_names",
      "api_key"
    )
  )
  expect_identical(tail(names(formals(get_airnow_forecast)), 1), "area")
})
