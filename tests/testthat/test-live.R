# Live checks against the real API. They run only when explicitly requested;
# once requested, a missing or placeholder key is an error. Each check is a
# fact from the spec's section 2 that a recorded fixture cannot see drifting.
skip_if_no_live_key <- function() {
  live_requested <- identical(Sys.getenv("AIRNOW_LIVE_TESTS"), "true")
  if (!live_requested) {
    testthat::skip_on_cran()
    testthat::skip("Live API tests were not requested")
  }

  key <- Sys.getenv("AIRNOW_API_KEY")
  if (!nzchar(key) || identical(key, "test-key")) {
    cli::cli_abort("{.envvar AIRNOW_LIVE_TESTS} is true, but no live {.envvar AIRNOW_API_KEY} is configured") # nolint
  }
}

live_request <- function(path, ...) {
  req_airnow() |>
    httr2::req_url_path_append(path) |>
    httr2::req_url_query(
      ...,
      format = "application/json",
      api_key = get_airnow_key(ask = FALSE)
    ) |>
    httr2::req_perform()
}

test_that("live: api_key is accepted and the response is served over HTTPS", { # nolint
  skip_if_no_live_key()
  resp <- live_request("forecast/current", zipCode = "90210")
  expect_equal(httr2::resp_status(resp), 200)
  expect_match(resp$url, "^https://")
})

test_that("live: distance is still ignored by the new observation service", {
  skip_if_no_live_key()
  a <- live_request(
    "observation/current/ziplatLong", latitude = 39.5, longitude = -116.9
  )
  b <- live_request(
    "observation/current/ziplatLong",
    latitude = 39.5, longitude = -116.9, distance = 300
  )
  expect_equal(nrow(resp_airnow_tibble(a)), 0)
  expect_equal(nrow(resp_airnow_tibble(b)), 0)
})

test_that("live: forecast/current accepts a reporting area code", {
  skip_if_no_live_key()
  result <- get_airnow_forecasts(area = "ca132")
  expect_true(nrow(result) > 0)
  expect_equal(unique(as.character(result$reporting_area_code)), "ca132")
})

test_that("live: area names still join and time columns are sane", {
  skip_if_no_live_key()
  local_area_code_cache()
  obs <- expect_no_warning(get_airnow_observations(zip = "90210"))
  expect_true(nrow(obs) > 0)
  expect_false(anyNA(obs$reporting_area_code))
  expect_false(anyNA(obs$utc_datetime))
  expect_true(all(obs$hour_observed >= 0L & obs$hour_observed <= 23L))
  # End-of-period labels for the latest completed hour fall inside this
  # window. (The one-hour offset itself can only be verified against the
  # old service, which is gone after 2026-09-30.)
  expect_true(all(obs$utc_datetime <= Sys.time() + 15 * 60))
  expect_true(all(obs$utc_datetime >= Sys.time() - 6 * 3600))
})

test_that("live: pollutant and category vocabularies are still recognised", {
  skip_if_no_live_key()
  fc <- expect_no_warning(get_airnow_forecasts(zip = "90210"))
  expect_false(anyNA(fc$parameter))
  expect_false(anyNA(fc$category_name))
})
