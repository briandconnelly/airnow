test_that("req_airnow() catches invalid inputs", {
  expect_error(req_airnow(throttle_rate = NULL))
  expect_error(req_airnow(throttle_rate = -1))
  expect_error(req_airnow(throttle_rate = NA_real_))
})

test_that("req_airnow() returns expected output", {
  result <- req_airnow()
  expect_s3_class(result, "httr2_request")
  expect_equal(result$url, "http://www.airnowapi.org/aq")
})
