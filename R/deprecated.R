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
#'
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
