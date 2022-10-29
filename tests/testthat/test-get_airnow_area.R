valid_call <- function(box = c(-125.394211, 45.295897, -116.736984, 49.172497),
                       parameters = "pm25",
                       start_time = NULL,
                       end_time = NULL,
                       monitor_type = "both",
                       data_type = c("aqi", "concentrations", "both"),
                       verbose = FALSE,
                       raw_concentrations = FALSE,
                       clean_names = TRUE,
                       api_key = get_airnow_token()) {
  get_airnow_area(
    box = box,
    parameters = parameters,
    start_time = start_time,
    end_time = end_time,
    monitor_type = monitor_type,
    data_type = data_type,
    verbose = verbose,
    raw_concentrations = raw_concentrations,
    clean_names = clean_names,
    api_key = api_key
  )
}

test_that("get_airnow_area() validates inputs properly", {
  # Box is a 4-element numeric vector of lon/lat pairs
  expect_error(valid_call(box = TRUE))
  expect_error(valid_call(box = 1))
  expect_error(valid_call(box = 1:3))
  expect_error(valid_call(box = 1:5))
  expect_error(valid_call(box = c(-181, 0, 0, 0)))
  expect_error(valid_call(box = c(0, -91, 0, 0)))
  expect_error(valid_call(box = c(0, 0, 181, 0)))
  expect_error(valid_call(box = c(0, 0, 0, 91)))
  expect_error(valid_call(box = c(0, 0, -1, 0)))
  expect_error(valid_call(box = c(0, 0, 0, -1)))

  # parameters is a list of 1+ "pm25", "ozone", "pm10", "co", "no2", "so2"
  expect_error(valid_call(parameters = NULL))
  expect_error(valid_call(parameters = NA_character_))
  expect_error(valid_call(parameters = NA_character_))
  expect_error(valid_call(parameters = ""))
  expect_error(valid_call(parameters = "aqi"))

  # start_time is NULL or a UTC date(time)
  # TODO

  # end_time is NULL or a UTC date(time)
  # TODO

  # both or neither of start_time and end_time must be set
  expect_error(valid_call(start_time = "2022-01-01", end_time = NULL))
  expect_error(valid_call(start_time = NULL, end_time = "2022-01-01"))

  # monitor_type is "permanent", "mobile", or "both"
  expect_error(valid_call(monitor_type = NULL))
  expect_error(valid_call(monitor_type = NA_character_))
  expect_error(valid_call(monitor_type = c("permanent", "mobile")))
  expect_error(valid_call(monitor_type = "invalid"))
  expect_error(valid_call(monitor_type = 1))

  # data_type is "aqi", "concentrations", or "both"
  expect_error(valid_call(data_type = NULL))
  expect_error(valid_call(data_type = NA_character_))
  expect_error(valid_call(data_type = c("aqi", "concentrations")))
  expect_error(valid_call(data_type = "invalid"))
  expect_error(valid_call(data_type = 1))

  # verbose is a scalar logical
  expect_error(valid_call(verbose = NULL))
  expect_error(valid_call(verbose = NA))
  expect_error(valid_call(verbose = 1))
  expect_error(valid_call(verbose = c(TRUE, FALSE)))

  # raw_concentrations is a scalar logical
  expect_error(valid_call(raw_concentrations = NULL))
  expect_error(valid_call(raw_concentrations = NA))
  expect_error(valid_call(raw_concentrations = 1))
  expect_error(valid_call(raw_concentrations = c(TRUE, FALSE)))

  # clean_names is a scalar logical
  expect_error(valid_call(clean_names = NULL))
  expect_error(valid_call(clean_names = NA))
  expect_error(valid_call(clean_names = 1))
  expect_error(valid_call(clean_names = c(TRUE, FALSE)))

  # api_key must be a scalar string
  expect_error(valid_call(api_key = NULL))
  expect_error(valid_call(api_key = NA_character_))
  expect_error(valid_call(api_key = ""))
})

rm(valid_call)


test_that("get_airnow_area() produces the expected outputs", {
  skip_if(
    condition = identical(Sys.getenv("AIRNOW_API_KEY"), ""),
    message = "AirNow API token is not set"
  )

  colnames_raw <- c(
    "Latitude",
    "Longitude",
    "UTC",
    "Parameter",
    "Unit",
    "AQI",
    "Category"
  )

  colnames_clean <- c(
    "latitude",
    "longitude",
    "datetime_observed",
    "parameter",
    "unit",
    "aqi",
    "category_number"
  )

  result <- get_airnow_area(
    box = c(-125.394211, 45.295897, -116.736984, 49.172497)
  )

  expect_true(is.data.frame(result))
  expect_true(tibble::is_tibble(result))

  expect_setequal(colnames(result), colnames_clean)

  result_allargs_clean <- get_airnow_area(
    box = c(-125.394211, 45.295897, -116.736984, 49.172497),
    data_type = "both",
    verbose = TRUE,
    raw_concentrations = TRUE
  )

  expect_true(is.data.frame(result_allargs_clean))
  expect_true(tibble::is_tibble(result_allargs_clean))

  expect_setequal(
    colnames(result_allargs_clean),
    c(
      colnames_clean,
      "value",
      "raw_concentration",
      "site_name",
      "site_agency",
      "aqs_code",
      "intl_aqs_code"
    )
  )

  result_noclean <- get_airnow_area(
    box = c(-125.394211, 45.295897, -116.736984, 49.172497),
    clean_names = FALSE
  )

  expect_true(is.data.frame(result_noclean))
  expect_true(tibble::is_tibble(result_noclean))

  expect_setequal(colnames(result_noclean), colnames_raw)


  result_allargs_noclean <- get_airnow_area(
    box = c(-125.394211, 45.295897, -116.736984, 49.172497),
    data_type = "both",
    verbose = TRUE,
    raw_concentrations = TRUE,
    clean_names = FALSE
  )

  expect_true(is.data.frame(result_allargs_noclean))
  expect_true(tibble::is_tibble(result_allargs_noclean))

  expect_setequal(
    colnames(result_allargs_noclean),
    c(
      colnames_raw,
      "Value",
      "RawConcentration",
      "SiteName",
      "AgencyName",
      "FullAQSCode",
      "IntlAQSCode"
    )
  )
})
