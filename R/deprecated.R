#' Deprecated functions
#'
#' @description These functions were deprecated in airnow 0.2.0 and will be
#'   removed in a future release. Each one warns and then calls its
#'   replacement.
#'
#' | Deprecated | Replacement |
#' |---|---|
#' | `get_airnow_token()` | [get_airnow_key()] |
#' | `set_airnow_token()` | [set_airnow_key()] |
#' | `get_airnow_area()` | [get_airnow_monitors()] |
#'
#' @return Each deprecated function returns whatever its replacement returns.
#' @name airnow-deprecated
#' @keywords internal
NULL


#' @rdname airnow-deprecated
#' @inheritParams get_airnow_key
#' @export
get_airnow_token <- function(ask = is_interactive()) {
  lifecycle::deprecate_warn("0.2.0", "get_airnow_token()", "get_airnow_key()")
  get_airnow_key(ask = ask)
}


#' @rdname airnow-deprecated
#' @param token The API key to use (deprecated spelling of `key`)
#' @export
set_airnow_token <- function(token = NULL, ask = is_interactive()) {
  lifecycle::deprecate_warn("0.2.0", "set_airnow_token()", "set_airnow_key()")
  set_airnow_key(key = token, ask = ask)
}


#' @rdname airnow-deprecated
#' @inheritParams get_airnow_monitors
#' @export
get_airnow_area <- function(box,
                            parameters = "pm25",
                            start_time = NULL,
                            end_time = NULL,
                            monitor_type = "both",
                            data_type = c("aqi", "concentrations", "both"),
                            verbose = FALSE,
                            raw_concentrations = FALSE,
                            clean_names = TRUE,
                            api_key = get_airnow_key()) {
  lifecycle::deprecate_warn("0.2.0", "get_airnow_area()", "get_airnow_monitors()") # nolint
  get_airnow_monitors(
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
