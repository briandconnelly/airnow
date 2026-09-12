test_that("key functions work when the variable is set", {
  test_key <- "00000000-0000-4000-8000-000000000000"
  withr::local_envvar(AIRNOW_API_KEY = test_key)

  expect_true(airnow_key_isset())
  expect_equal(get_airnow_key(ask = FALSE), test_key)

  new_key <- "123-new-key"
  expect_message(set_airnow_key(key = new_key, ask = FALSE))
  expect_true(airnow_key_isset())
  expect_equal(get_airnow_key(ask = FALSE), new_key)
})

test_that("key functions work when the variable is not set", {
  withr::local_envvar(AIRNOW_API_KEY = NA)
  expect_false(airnow_key_isset())
  expect_error(get_airnow_key(ask = FALSE))

  test_key <- "00000000-0000-4000-8000-000000000000"
  expect_silent(set_airnow_key(key = test_key, ask = FALSE))
  expect_true(airnow_key_isset())
  expect_equal(get_airnow_key(ask = FALSE), test_key)
})

test_that("an empty string counts as unset", {
  withr::local_envvar(AIRNOW_API_KEY = "")
  expect_false(airnow_key_isset())
  expect_error(get_airnow_key(ask = FALSE))
})

test_that("set_airnow_key() rejects non-string keys", {
  withr::local_envvar(AIRNOW_API_KEY = NA)
  expect_error(set_airnow_key(key = 123, ask = FALSE))
  expect_error(set_airnow_key(key = "", ask = FALSE))
  expect_error(set_airnow_key(key = c("a", "b"), ask = FALSE))
})

test_that("token functions are deprecated aliases for the key functions", {
  withr::local_envvar(AIRNOW_API_KEY = "abc")

  lifecycle::expect_deprecated(result <- get_airnow_token(ask = FALSE))
  expect_equal(result, "abc")

  lifecycle::expect_deprecated(
    suppressMessages(set_airnow_token(token = "def", ask = FALSE))
  )
  expect_equal(Sys.getenv("AIRNOW_API_KEY"), "def")
})
