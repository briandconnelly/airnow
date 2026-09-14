test_that("lookup_areas_by_name() returns zero, one, or many rows", {
  expect_equal(nrow(lookup_areas_by_name("Napa")), 1)
  expect_equal(nrow(lookup_areas_by_name("Aberdeen")), 2)
  expect_equal(nrow(lookup_areas_by_name("Atlantis")), 0)
})

test_that("nearest_area() picks the closest candidate", {
  candidates <- lookup_areas_by_name("Aberdeen")
  # Near Aberdeen, WA
  expect_equal(nearest_area(47.1, -123.8, candidates)$reporting_area_code, "wa008") # nolint
  # Near Aberdeen, SD
  expect_equal(nearest_area(45.5, -98.5, candidates)$reporting_area_code, "sd009") # nolint
})

test_that("resolve_area_code() resolves a zip through the API and memoises", {
  local_area_code_cache()

  httptest2::with_mock_dir("resolve_zip", {
    expect_equal(resolve_area_code(zip = "90210"), "ca132")
  })

  # Second call must come from the memo: any request now is an error
  httptest2::without_internet({
    expect_equal(resolve_area_code(zip = "90210"), "ca132")
  })
  expect_named(the$area_codes, "zip:90210")
})

test_that("resolve_area_code() aborts when the API finds no area", {
  local_area_code_cache()
  testthat::local_mocked_bindings(
    perform_airnow = function(req) tibble::tibble()
  )
  expect_error(
    resolve_area_code(latitude = 39.5, longitude = -116.9),
    "No AirNow reporting area"
  )
})

test_that("resolve_area_code() validates its location like check_location()", {
  expect_error(resolve_area_code())
  expect_error(resolve_area_code(zip = "1234"))
  expect_error(resolve_area_code(latitude = 91, longitude = 0))
})

test_that("historical ZIP resolution uses the bundled crosswalk offline", {
  httptest2::without_internet({
    expect_equal(resolve_historical_area_code(zip = "98101"), "wa004")
    expect_equal(resolve_historical_area_code(zip = "00601"), "pr003")
  })
})

test_that("historical resolution falls back live for a crosswalk miss", {
  calls <- 0L
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      calls <<- calls + 1L
      "ca132"
    }
  )

  expect_equal(resolve_historical_area_code(zip = "99999"), "ca132")
  expect_equal(calls, 1L)
})

test_that("historical resolution explains successful no-data lookups", {
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      cli::cli_abort(
        "No AirNow reporting area was found for the given location",
        class = "airnow_no_reporting_area"
      )
    }
  )

  expect_error(
    resolve_historical_area_code(zip = "99999"),
    "explicit.*area"
  )
  expect_error(
    resolve_historical_area_code(latitude = 39.5, longitude = -116.9),
    "explicit.*area"
  )
})

test_that("historical resolution preserves unrelated API failures", {
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      cli::cli_abort("Request not authenticated", class = "airnow_auth_error")
    }
  )

  expect_error(
    resolve_historical_area_code(zip = "99999"),
    class = "airnow_auth_error"
  )
})

test_that("join_areas_by_name() fills geography for an unambiguous name", {
  x <- tibble::tibble(
    reportingAreaName = c("Napa", "Napa"),
    parameterName = c("OZONE", "PM2.5")
  )
  result <- httptest2::without_internet(
    join_areas_by_name(x, latitude = 38.3, longitude = -122.3)
  )
  expect_equal(result$reportingAreaCode, c("ca064", "ca064"))
  expect_equal(result$stateCode, c("CA", "CA"))
  expect_equal(result$reportingAreaAgency, rep("Bay Area Air District", 2))
  expect_type(result$latitude, "double")
  expect_false(anyNA(result$latitude))
})

test_that("join_areas_by_name() resolves colliding names offline for coordinates", { # nolint
  x <- tibble::tibble(reportingAreaName = "Aberdeen")
  result <- httptest2::without_internet(
    join_areas_by_name(x, latitude = 47.1, longitude = -123.8)
  )
  expect_equal(result$reportingAreaCode, "wa008")
  expect_equal(result$stateCode, "WA")
})

test_that("join_areas_by_name() resolves colliding names via the API for zips", { # nolint
  local_area_code_cache()
  calls <- 0
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      calls <<- calls + 1
      "sd009"
    }
  )
  x <- tibble::tibble(reportingAreaName = c("Aberdeen", "Aberdeen"))
  result <- join_areas_by_name(x, zip = "57401")
  expect_equal(result$reportingAreaCode, c("sd009", "sd009"))
  expect_equal(result$stateCode, c("SD", "SD"))
  expect_equal(calls, 1)
})

test_that("join_areas_by_name() treats a resolver failure as a join miss", {
  local_area_code_cache()
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) cli::cli_abort("No AirNow reporting area") # nolint
  )
  x <- tibble::tibble(reportingAreaName = "Aberdeen", parameterName = "OZONE")
  expect_warning(result <- join_areas_by_name(x, zip = "57401"), "Aberdeen")
  expect_equal(nrow(result), 1)
  expect_true(is.na(result$reportingAreaCode))
  expect_equal(result$parameterName, "OZONE")
})

test_that("join_areas_by_name() warns and leaves NA on a miss", {
  x <- tibble::tibble(reportingAreaName = c("Atlantis", "Napa"))
  expect_warning(
    result <- join_areas_by_name(x, zip = "90210"),
    "Atlantis"
  )
  expect_equal(result$reportingAreaCode, c(NA, "ca064"))
  expect_equal(result$stateCode, c(NA, "CA"))
  expect_true(is.na(result$latitude[1]))
  expect_equal(nrow(result), 2)
})

test_that("join_areas_by_name() handles zero rows", {
  x <- tibble::tibble(reportingAreaName = character(0))
  result <- join_areas_by_name(x, zip = "90210")
  expect_equal(nrow(result), 0)
  expect_true(all(c("reportingAreaCode", "stateCode", "latitude", "longitude", "reportingAreaAgency") %in% names(result))) # nolint
})

test_that("join_areas_by_code() fills coordinates and missing state codes", {
  x <- tibble::tibble(
    reportingAreaCode = c("ca064", "ca132", "zz999"),
    stateCode = c("CA", NA, NA)
  )
  expect_warning(result <- join_areas_by_code(x), "zz999")
  expect_equal(result$stateCode, c("CA", "CA", NA))
  expect_equal(is.na(result$latitude), c(FALSE, FALSE, TRUE))

  no_state <- tibble::tibble(reportingAreaCode = "ca064")
  result <- join_areas_by_code(no_state)
  expect_equal(result$stateCode, "CA")
})
