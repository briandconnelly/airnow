test_that("get_airnow_area() warns and delegates to get_airnow_monitors()", {
  seen <- NULL
  testthat::local_mocked_bindings(
    get_airnow_monitors = function(box, ...) {
      seen <<- box
      tibble::tibble(ok = TRUE)
    }
  )
  box <- c(-125.394211, 45.295897, -116.736984, 49.172497)
  lifecycle::expect_deprecated(result <- get_airnow_area(box = box))
  expect_equal(seen, box)
  expect_equal(result$ok, TRUE)
})
