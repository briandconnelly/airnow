test_that("get_airnow_area() validates inputs properly", {

  # Box is a 4-element numeric vector of lat/lon pairs
  expect_error(get_airnow_area(box = TRUE))
})
