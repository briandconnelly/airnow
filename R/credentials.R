#' Manage AirNow API Tokens
#'
#' @description `get_airnow_token()` returns the configured AirNow API token or
#'   errors if it is not set.
#'
#' @return `get_airnow_token()` returns a string containing the current
#' user or group key or an empty string if not set. If the user is not set but
#' `ask` is `TRUE`, the user will be prompted for a key.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_token()
#' }
get_airnow_token <- function(ask = is_interactive()) {
  if (!airnow_token_isset()) {
    set_airnow_token(ask = ask)
  } else {
    Sys.getenv("AIRNOW_API_KEY")
  }
}


#' @rdname get_airnow_token
#' @description `set_airnow_token()` sets the AirNow API token to the given
#'   value for the current session. To use this permanently, save it as
#'   `AIRNOW_API_KEY` in your `~/.Renviron` file.
#' @param token Token to use
#' @param ask Whether or not to ask for the key if none is provided. Note that
#'   this only works for interactive sessions.
#' @export
#' @examples
#' \dontrun{
#' set_airnow_token(token = "4d36e978-e325-11cec1-08002be10318")
#' }
set_airnow_token <- function(token = NULL, ask = is_interactive()) {
  if (is.null(token)) {
    if (ask && is_interactive()) {
      cli::cli_alert_info("Your AirNow API token is not set. Visit {.url https://docs.airnowapi.org/account/request/} to create an account.") # nolint
      in_user <- readline("Please enter your API token: ")
      Sys.setenv("AIRNOW_API_KEY" = in_user)
    } else {
      cli::cli_abort("Set AirNow API token by providing value for argument {.arg token} or setting {.envvar AIRNOW_API_KEY} in your {.file ~/.Renviron} file.") # nolint
    }
  } else {
    if (airnow_token_isset()) {
      cli::cli_alert_info("AirNow API token is already set. Overriding for this session only.\nTo use this token permanently, update {.envvar AIRNOW_API_KEY} it in your {.file ~/.Renviron} file.") # nolint
    }
    Sys.setenv(AIRNOW_API_KEY = token)
  }
}

airnow_token_isset <- function() {
  !is.na(Sys.getenv("AIRNOW_API_KEY", unset = NA_character_))
}
