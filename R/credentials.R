#' Manage your AirNow API key
#'
#' @description `get_airnow_key()` returns the configured AirNow API key. If
#'   no key is set and `ask` is `TRUE` in an interactive session, you are
#'   prompted for one; otherwise an error is raised.
#'
#' The key is read from the `AIRNOW_API_KEY` environment variable. To set it
#' permanently, add `AIRNOW_API_KEY=your-key` to your `~/.Renviron` file.
#' Keys are issued at <https://docs.airnowapi.org/account/request/>.
#'
#' @param ask Whether to prompt for the key if none is set. Prompting only
#'   works in interactive sessions.
#'
#' @return `get_airnow_key()` returns a string.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_key()
#' }
get_airnow_key <- function(ask = is_interactive()) {
  if (!airnow_key_isset()) {
    set_airnow_key(ask = ask)
  }
  Sys.getenv("AIRNOW_API_KEY")
}


#' @rdname get_airnow_key
#' @description `set_airnow_key()` sets the AirNow API key for the current
#'   session.
#' @param key The API key to use. If `NULL` and `ask` is `TRUE`, you are
#'   prompted for one.
#' @return `set_airnow_key()` returns the key, invisibly.
#' @export
#' @examples
#' \dontrun{
#' set_airnow_key(key = "4d36e978-e325-11ce-bfc1-08002be10318")
#' }
set_airnow_key <- function(key = NULL, ask = is_interactive()) {
  if (is.null(key)) {
    if (ask && is_interactive()) {
      cli::cli_alert_info("Your AirNow API key is not set. Visit {.url https://docs.airnowapi.org/account/request/} to create an account.") # nolint
      key <- readline("Please enter your API key: ")
    } else {
      cli::cli_abort("Set your AirNow API key by providing {.arg key} or by setting {.envvar AIRNOW_API_KEY} in your {.file ~/.Renviron} file.") # nolint
    }
  } else if (airnow_key_isset()) {
    cli::cli_alert_info("AirNow API key is already set. Overriding for this session only.\nTo use this key permanently, update {.envvar AIRNOW_API_KEY} in your {.file ~/.Renviron} file.") # nolint
  }

  if (!is_string(key) || !nzchar(key)) {
    cli::cli_abort("{.arg key} must be a non-empty string")
  }

  Sys.setenv(AIRNOW_API_KEY = key)
  invisible(key)
}


airnow_key_isset <- function() {
  nzchar(Sys.getenv("AIRNOW_API_KEY", unset = ""))
}
