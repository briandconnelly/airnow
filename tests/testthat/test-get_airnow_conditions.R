test_that("get_airnow_conditions() catches invalid inputs", {

  # zip is a 5-digit numeric string (or integer)
  expect_error(get_airnow_conditions(zip = NULL))
  expect_error(get_airnow_conditions(zip = NA_character_))
  expect_error(get_airnow_conditions(zip = "98101-1234"))

  # latitude is a scalar number between -90 and 90, inclusive
  expect_error(get_airnow_conditions(zip = NULL, latitude = NA_real_, longitude = 0)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = NULL, longitude = 0)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = 92.0, longitude = 0)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = -92.0, longitude = 0)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = c(45, 45), longitude = 0)) # nolint

  # longitude is a scalar number between -180 and 80, inclusive
  expect_error(get_airnow_conditions(zip = NULL, latitude = NA_real_, longitude = NA_real)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = NULL, longitude = NULL)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = 0, longitude = 181.0)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = 0, longitude = -181.0)) # nolint
  expect_error(get_airnow_conditions(zip = NULL, latitude = 0, longitude = c(93, 15))) # nolint

  # distance is NULL or a non-negative scalar number
  expect_error(get_airnow_conditions(zip = "98101", distance = NA_real_))
  expect_error(get_airnow_conditions(zip = "98101", distance = -30))
  expect_error(get_airnow_conditions(zip = "98101", distance = 1:5))

  # clean_names is a logical scalar
  expect_error(get_airnow_conditions(zip = "98101", clean_names = NULL))
  expect_error(get_airnow_conditions(zip = "98101", clean_names = NA))
  expect_error(get_airnow_conditions(zip = "98101", clean_names = 1))
  expect_error(get_airnow_conditions(zip = "98101", clean_names = c(TRUE, FALSE))) # nolint
})


test_that("get_airnow_conditions() produces the expected outputs", {
  skip_if(
    condition = identical(Sys.getenv("AIRNOW_API_KEY"), ""),
    message = "AirNow API token is not set"
  )

  result <- get_airnow_conditions(zip = "98101")

  expect_true(is.data.frame(result))
  expect_true(tibble::is_tibble(result))

  expect_setequal(
    colnames(result),
    c(
      "date_observed",
      "hour_observed",
      "local_time_zone",
      "reporting_area",
      "state_code",
      "latitude",
      "longitude",
      "parameter",
      "aqi",
      "category_number",
      "category_name"
    )
  )

  result_noclean <- get_airnow_conditions(zip = "98101", clean_names = FALSE)

  expect_true(is.data.frame(result_noclean))
  expect_true(tibble::is_tibble(result_noclean))

  expect_setequal(
    colnames(result_noclean),
    c(
      "DateObserved",
      "HourObserved",
      "LocalTimeZone",
      "ReportingArea",
      "StateCode",
      "Latitude",
      "Longitude",
      "ParameterName",
      "AQI",
      "Category.Number",
      "Category.Name"
    )
  )
})
