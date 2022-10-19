#' Create a Request for the AirNow API
#'
#' The AirNow API enforces [rate limits](https://docs.airnowapi.org/faq#rateLimits). # nolint
#' For most endpoints, this is 500 requests per hour.
#'
#' @param throttle_rate Numeric value indicating the maximum number of requests
#'   per second.
#'
#' @return An [httr2::request] object
#' @noRd
#'
req_airnow <- function(throttle_rate = 500 / 3600) {
  if (!is_double(throttle_rate, n = 1) || throttle_rate < 0) {
    cli::cli_abort("{.arg throttle_rate} must be a positive number")
  }

  httr2::request("http://www.airnowapi.org/aq") |>
    httr2::req_user_agent(glue("airnow v{packageVersion('airnow')} <https://github.com/briandconnelly/airnow>")) |> # nolint
    httr2::req_throttle(rate = throttle_rate)
}
