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

  httr2::request("https://www.airnowapi.org/aq") |>
    httr2::req_user_agent(glue("airnow v{packageVersion('airnow')} <https://github.com/briandconnelly/airnow>")) |> # nolint
    httr2::req_throttle(rate = throttle_rate) |>
    httr2::req_error(body = airnow_error_messages)
}

#' Extract AirNow error messages from a response
#'
#' AirNow reports problems as `{"WebServiceError":[{"Message":"..."}]}`,
#' under a 200 for "no data" and under 4xx for other failures.
#'
#' @param resp An [httr2::response] object
#' @return A character vector of messages, or `NULL` if the body is not an
#'   AirNow error envelope.
#' @noRd
airnow_error_messages <- function(resp) {
  text <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
  parsed <- tryCatch(jsonlite::fromJSON(text), error = function(e) NULL)
  if (is.list(parsed) && !is.data.frame(parsed) &&
    !is.null(parsed$WebServiceError)) {
    as.character(parsed$WebServiceError$Message)
  } else {
    NULL
  }
}

# Messages the API uses to say "nothing matched", which are not errors.
airnow_no_data_pattern <- "^(Error - )?There (are|is) no "

#' Convert an AirNow response into a tibble
#'
#' @param resp An [httr2::response] object with a JSON body
#' @return A tibble. Zero rows (and zero columns) when the API reports that no
#'   data matched the request.
#' @noRd
resp_airnow_tibble <- function(resp) {
  msgs <- airnow_error_messages(resp)
  if (!is.null(msgs)) {
    if (all(grepl(airnow_no_data_pattern, msgs))) {
      return(tibble::tibble())
    }
    cli::cli_abort(c(
      "The AirNow API returned an error:",
      set_names(msgs, rep("x", length(msgs)))
    ))
  }

  parsed <- tryCatch(
    resp |>
      httr2::resp_body_string() |>
      jsonlite::fromJSON(flatten = TRUE),
    error = function(e) {
      cli::cli_abort(
        c(
          "The AirNow API returned a response that could not be parsed as JSON", # nolint
          "i" = "HTTP status {httr2::resp_status(resp)}"
        ),
        parent = e
      )
    }
  )

  tibble::as_tibble(parsed)
}

#' Perform an AirNow request and parse the result
#'
#' @param req An [httr2::request] built with [req_airnow()]
#' @return A tibble; see [resp_airnow_tibble()]
#' @noRd
perform_airnow <- function(req) {
  req |>
    httr2::req_perform() |>
    resp_airnow_tibble()
}
