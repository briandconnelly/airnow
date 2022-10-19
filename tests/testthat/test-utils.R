test_that("clean_names() errors with unnamed inputs", {
  x <- 21
  expect_error(clean_names(x))
})

test_that("clean_names() returns a named output", {
  pets <- list("dogs" = TRUE, "cats" = FALSE, "ducks" = NULL)

  expect_named(clean_names(pets))
  expect_setequal(names(clean_names(pets)), names(pets))
})
