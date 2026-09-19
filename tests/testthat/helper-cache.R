# Empty the session-level area-code memo for the duration of a test and
# restore it afterwards. `the` is defined in R/areas.R (Task 2); before that
# file exists this helper is simply unused.
local_area_code_cache <- function(env = parent.frame()) {
  old <- the$area_codes
  the$area_codes <- list()
  withr::defer(the$area_codes <- old, envir = env)
}
