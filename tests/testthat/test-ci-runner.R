clean_live_results <- function() {
  data.frame(
    nb = 2L,
    failed = 0L,
    skipped = FALSE,
    error = FALSE,
    warning = 0L
  )
}

test_that("assert_live_results() accepts an executed clean suite", {
  expect_invisible(assert_live_results(clean_live_results()))
})

test_that("assert_live_results() rejects empty and incomplete results", {
  expect_error(assert_live_results(data.frame()), "required columns")

  empty <- clean_live_results()[0, ]
  expect_error(assert_live_results(empty), "No live tests")

  zero <- clean_live_results()
  zero$nb <- 0L
  expect_error(assert_live_results(zero), "no expectations")
})

test_that("assert_live_results() rejects every non-clean outcome", {
  for (field in c("failed", "skipped", "error", "warning")) {
    result <- clean_live_results()
    result[[field]] <- 1L
    expect_error(assert_live_results(result), field, fixed = TRUE)
  }

  missing_count <- clean_live_results()
  missing_count$failed <- NA_integer_
  expect_error(assert_live_results(missing_count), "must not contain NA")
})
