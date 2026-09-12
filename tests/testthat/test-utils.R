test_that("clean_names() errors with unnamed inputs", {
  x <- 21
  expect_error(clean_names(x))
})

test_that("clean_names() returns a named output", {
  pets <- list("dogs" = TRUE, "cats" = FALSE, "ducks" = NULL)

  expect_named(clean_names(pets))
  expect_setequal(names(clean_names(pets)), names(pets))
})

test_that("clean_names() keeps the legacy explicit mapping", {
  x <- list(DateObserved = 1, Category.Name = 2, UTC = 3, FullAQSCode = 4)
  expect_named(
    clean_names(x),
    c("date_observed", "category_name", "datetime_observed", "aqs_code")
  )
})

test_that("clean_names() converts lowerCamelCase generically", {
  x <- list(
    reportingAreaCode = 1, dateValid = 2, actionDay = 3, latitude = 4,
    consideredMonitors = 5, utcDatetime = 6, source = 7
  )
  expect_named(clean_names(x), c(
    "reporting_area_code", "date_valid", "action_day", "latitude",
    "considered_monitors", "utc_datetime", "source"
  ))
})

test_that("clean_names() maps the 2026 API's special names", {
  x <- list(
    parameterName = 1, reportingAreaName = 2, nowcastAQI = 3,
    aqiCategoryName = 4, dailyAQI = 5, dailyAQICategoryName = 6, siteID = 7
  )
  expect_named(clean_names(x), c(
    "parameter", "reporting_area", "aqi", "category_name", "aqi",
    "category_name", "site_id"
  ))
})

test_that("camel_to_snake() handles acronyms", {
  expect_equal(camel_to_snake("nowcastAQI"), "nowcast_aqi")
  expect_equal(
    camel_to_snake("dailyAQICategoryName"),
    "daily_aqi_category_name"
  )
  expect_equal(camel_to_snake("siteID"), "site_id")
  expect_equal(camel_to_snake("already_snake"), "already_snake")
})
