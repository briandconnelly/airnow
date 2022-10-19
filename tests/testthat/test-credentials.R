test_that("Credentials functions work as expected when env is set", {
  test_token <- "329E30B6-1474-4644-B238-6F36E2BF1912"
  withr::local_envvar(AIRNOW_API_KEY = test_token)

  expect_true(airnow_token_isset())
  expect_equal(get_airnow_token(ask = FALSE), test_token)

  # New token is used once set
  new_token <- "123-new-token"
  expect_message(set_airnow_token(token = new_token, ask = FALSE))
  expect_true(airnow_token_isset())
  expect_equal(get_airnow_token(ask = FALSE), new_token)
})

test_that("Credentials functions work as expected when env is not set", {
  withr::local_envvar(AIRNOW_API_KEY = NA)
  expect_false(airnow_token_isset())
  expect_error(get_airnow_token(ask = FALSE))

  test_token <- "329E30B6-1474-4644-B238-6F36E2BF1912"
  set_airnow_token(token = test_token)
  expect_true(airnow_token_isset())
  expect_equal(get_airnow_token(ask = FALSE), test_token)
})
