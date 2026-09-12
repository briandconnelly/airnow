test_that("req_airnow() catches invalid inputs", {
  expect_error(req_airnow(throttle_rate = NULL))
  expect_error(req_airnow(throttle_rate = -1))
  expect_error(req_airnow(throttle_rate = NA_real_))
})

test_that("req_airnow() uses HTTPS", {
  result <- req_airnow()
  expect_s3_class(result, "httr2_request")
  expect_equal(result$url, "https://www.airnowapi.org/aq")
})

test_that("airnow_error_messages() extracts messages from the error envelope", {
  resp <- httr2::response_json(
    status_code = 401,
    body = list(WebServiceError = list(list(
      Message = "Request not authenticated."
    )))
  )
  expect_equal(airnow_error_messages(resp), "Request not authenticated.")

  plain <- httr2::response_json(status_code = 200, body = list(list(aqi = 1)))
  expect_null(airnow_error_messages(plain))

  not_json <- httr2::response(status_code = 500, body = charToRaw("oops"))
  expect_null(airnow_error_messages(not_json))
})

test_that("resp_airnow_tibble() parses a normal payload", {
  resp <- httr2::response_json(
    status_code = 200,
    body = list(list(aqi = 53L, parameterName = "PM2.5"))
  )
  result <- resp_airnow_tibble(resp)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$parameterName, "PM2.5")
})

test_that("resp_airnow_tibble() returns an empty tibble for empty arrays", {
  resp <- httr2::response_json(status_code = 200, body = list())
  result <- resp_airnow_tibble(resp)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("resp_airnow_tibble() treats 'no data' errors as empty results", {
  msgs <- c(
    "There are no observations available for the requested latitude/longitude: No observations were found for all monitors within 50 miles.", # nolint
    "Error - There is no reporting area at your searched location"
  )
  for (msg in msgs) {
    resp <- httr2::response_json(
      status_code = 200,
      body = list(WebServiceError = list(list(Message = msg)))
    )
    result <- resp_airnow_tibble(resp)
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 0)
  }
})

test_that("resp_airnow_tibble() aborts with the API message for other errors", {
  resp <- httr2::response_json(
    status_code = 200,
    body = list(WebServiceError = list(list(Message = "Invalid date format.")))
  )
  expect_error(resp_airnow_tibble(resp), "Invalid date format")
})

test_that("resp_airnow_tibble() handles malformed JSON with a friendly error", {
  resp <- httr2::response(status_code = 200, body = charToRaw("not json"))
  expect_error(resp_airnow_tibble(resp), "could not be parsed")
})

test_that("resp_airnow_tibble() handles empty body with a friendly error", {
  resp <- httr2::response(status_code = 200)
  expect_error(resp_airnow_tibble(resp), "could not be parsed")
})
