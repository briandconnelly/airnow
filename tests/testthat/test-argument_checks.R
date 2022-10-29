test_that("check_zip() validates input properly", {
  # zip must be a 5-digit numeric string or integer
  expect_error(check_zip())
  expect_error(check_zip("123456"))
  expect_error(check_zip(123456))
  expect_error(check_zip("90210-1234"))
  expect_error(check_zip(NA_character_))

  expect_equal(check_zip("90210"), "90210")
})


test_that("check_latitude() validates input properly", {
  # latitude must be a numeric value between -90 and 90, inclusive
  expect_error(check_latitude())
  expect_error(check_latitude(-91))
  expect_error(check_latitude(91))
  expect_error(check_latitude(c(45, 45)))
  expect_error(check_latitude(NA_real_))
  expect_error(check_latitude(NULL))

  expect_equal(check_latitude(12.345), 12.345)
})


test_that("check_longitude() validates input properly", {
  # longitude must be a numeric value between -180 and 180, inclusive
  expect_error(check_longitude())
  expect_error(check_longitude(-181))
  expect_error(check_longitude(181))
  expect_error(check_longitude(c(45, 45)))
  expect_error(check_longitude(NA_real_))
  expect_error(check_longitude(NULL))

  expect_equal(check_longitude(123.456), 123.456)
})


test_that("check_location() validates input properly", {
  expect_error(check_location())

  # Warning produced when both zip and latitide and/or longitude given
  expect_warning(check_location(zip = "90210", latitude = 12.345))
  expect_warning(check_location(zip = "90210", longitude = -23.456))

  # Both lat/lon must be specified, valid
  expect_error(check_location(latitude = 12.345))
  expect_error(check_location(longitude = -23.456))
  expect_error(check_location(latitude = 12.345, longitude = -181))
  expect_error(check_location(latitude = 12.345, longitude = 181))
  expect_error(check_location(latitude = 90.1, longitude = -23.456))
  expect_error(check_location(latitude = -90.1, longitude = -23.456))
  expect_error(check_location(latitude = NA_real_, longitude = -23.456))
  expect_error(check_location(latitude = 12.345, longitude = NA_real))
})

test_that("check_location() produces the expected output given a ZIP code", {
  test_zip_int <- 90210
  test_zip_str <- "90210"

  result_int <- check_location(zip = test_zip_int)

  expect_named(result_int)
  expect_true(is.list(result_int))
  expect_setequal(names(result_int), c("type", "zip", "latitude", "longitude"))
  expect_equal(result_int$type, "zipCode")
  expect_equal(result_int$zip, as.character(test_zip_int))

  result_str <- check_location(zip = test_zip_str)

  expect_named(result_str)
  expect_true(is.list(result_str))
  expect_setequal(names(result_str), c("type", "zip", "latitude", "longitude"))
  expect_equal(result_str$type, "zipCode")
  expect_equal(result_str$zip, test_zip_str)
})

test_that("check_location() produces the expected output given lat/lon pair", {
  test_lat <- 12.345
  test_lon <- -23.456

  result <- check_location(latitude = test_lat, longitude = test_lon)
  expect_named(result)
  expect_true(is.list(result))
  expect_setequal(names(result), c("type", "zip", "latitude", "longitude"))
  expect_equal(result$type, "latLong")
  expect_equal(result$latitude, test_lat)
  expect_equal(result$longitude, test_lon)
})


test_that("check_distance() catches invalid input", {
  # distance must be a scalar number >= 0 or NULL
  expect_error(check_distance(TRUE))
  expect_error(check_distance(-1))
  expect_error(check_distance(c(1, 2)))
  expect_error(check_distance(NA_real_))
})

test_that("check_distance() returns expected values", {
  # NULL is ok, returning NULL
  expect_true(is.null(check_distance(NULL)))

  # Valid values pass through
  expect_equal(check_distance(34), 34)
})


test_that("check_date() catches invalid input", {
  expect_error(check_date("20220101"))
  expect_error(check_date("2022-1-1"))
  expect_error(check_date("Aug 28, 2010"))
})

test_that("check_date() returns expected values", {
  valid_dates <- c("2022-01-01", "1980-01-02", "2022-11-12")

  for (i in valid_dates) {
    expect_equal(check_date(i), i)
  }

  # NULL is ok, returning NULL
  expect_true(is.null(check_date(NULL)))
})


test_that("check_bounding_box() catches invalid input", {
  expect_error(check_bounding_box(12))
  expect_error(check_bounding_box(1:3))
  expect_error(check_bounding_box(1:5))

  expect_error(check_bounding_box(c(-181, 0, 0, 0)))
  expect_error(check_bounding_box(c(0, -91, 0, 0)))
  expect_error(check_bounding_box(c(0, 0, 181, 0)))
  expect_error(check_bounding_box(c(0, 0, 0, 91)))

  expect_error(check_bounding_box(c(0, 0, -1, 0)))
  expect_error(check_bounding_box(c(0, 0, 0, -1)))
})

test_that("check_bounding_box() returns expected values", {
  valid_bounding_boxes <- list(
    c(1, 2, 3, 4),
    c(-122.3405, 47.562, -122.3405, 47.562),
    c(122.3405, -47.562, 122.3405, -47.562)
  )

  for (i in valid_bounding_boxes) {
    result <- airnow:::check_bounding_box(i)
    expect_equal(result, i)
  }
})
