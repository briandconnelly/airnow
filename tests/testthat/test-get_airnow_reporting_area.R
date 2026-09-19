test_that("get_airnow_reporting_area() validates its location before any request", { # nolint
  httptest2::without_internet({
    expect_error(get_airnow_reporting_area(), "must be specified")
    expect_error(get_airnow_reporting_area(zip = "1234"), "5-digit")
    expect_error(
      get_airnow_reporting_area(latitude = 91, longitude = 0),
      "between -90 and 90"
    )
    expect_error(get_airnow_reporting_area(latitude = 0), "must be specified")
  })
})

test_that("get_airnow_reporting_area() returns one row for a zip", {
  local_area_code_cache()
  httptest2::with_mock_dir("reporting_area", {
    result <- get_airnow_reporting_area(zip = "90210")
  })
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_named(result, c(
    "reporting_area_code", "reporting_area", "state_code",
    "latitude", "longitude"
  ))
  expect_equal(result$reporting_area_code, "ca132")
  expect_equal(result$reporting_area, "NW Coastal LA")
  expect_equal(result$state_code, "CA")
})

test_that("get_airnow_reporting_area() falls back to the ZIP crosswalk without a current forecast", { # nolint
  local_area_code_cache()
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      cli::cli_abort(
        "No AirNow reporting area was found for the given location",
        class = "airnow_no_reporting_area"
      )
    }
  )

  result <- get_airnow_reporting_area(zip = "98101")
  expect_equal(result$reporting_area_code, "wa004")
  expect_equal(result$state_code, "WA")
})

test_that("get_airnow_reporting_area() errors when neither lookup finds an area", { # nolint
  local_area_code_cache()
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      cli::cli_abort(
        "No AirNow reporting area was found for the given location",
        class = "airnow_no_reporting_area"
      )
    }
  )

  expect_error(
    get_airnow_reporting_area(zip = "99999"),
    class = "airnow_no_reporting_area"
  )
  expect_error(
    get_airnow_reporting_area(latitude = 39.5, longitude = -116.9),
    class = "airnow_no_reporting_area"
  )
})

test_that("get_airnow_reporting_area() passes unrelated API failures through", { # nolint
  local_area_code_cache()
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      cli::cli_abort("Request not authenticated", class = "airnow_auth_error")
    }
  )

  expect_error(
    get_airnow_reporting_area(zip = "98101"),
    class = "airnow_auth_error"
  )
})

test_that("get_airnow_reporting_area() warns when the code is not in the table", { # nolint
  local_area_code_cache()
  testthat::local_mocked_bindings(resolve_area_code = function(...) "zz999")
  expect_warning(result <- get_airnow_reporting_area(zip = "90210"), "zz999")
  expect_equal(result$reporting_area_code, "zz999")
  expect_true(is.na(result$reporting_area))
})
