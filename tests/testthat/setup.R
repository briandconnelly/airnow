# Tests replay recorded fixtures, so they never need a real key. Provide a
# placeholder when none is set so credential checks pass on CI, CRAN, and
# contributors' machines. When a real key IS set (locally, for recording),
# leave it alone.
if (!nzchar(Sys.getenv("AIRNOW_API_KEY"))) {
  withr::local_envvar(
    AIRNOW_API_KEY = "test-key",
    .local_envir = testthat::teardown_env()
  )
}
