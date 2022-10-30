test_that("aqi_color() catches invalid inputs", {
  expect_error(aqi_color(-1))
  expect_error(aqi_color(501))
  expect_error(aqi_color(NULL))
  expect_error(aqi_color(NA_integer_))
  expect_error(aqi_color(c()))
  expect_error(aqi_color(20, 30, -1))
  expect_error(aqi_color(20, 30, NULL))
})

test_that("aqi_color() returns expected results", {
  expect_equal(aqi_color(0), "#00E400")
  expect_equal(aqi_color(0), aqi_color(50))

  expect_equal(aqi_color(51), "#FFFF00")
  expect_equal(aqi_color(51), aqi_color(100))

  expect_equal(aqi_color(101), "#FF7E00")
  expect_equal(aqi_color(101), aqi_color(150))

  expect_equal(aqi_color(151), "#FF0000")
  expect_equal(aqi_color(151), aqi_color(200))

  expect_equal(aqi_color(201), "#8F3F97")
  expect_equal(aqi_color(201), aqi_color(300))

  expect_equal(aqi_color(301), "#7E0023")
  expect_equal(aqi_color(301), aqi_color(500))

  expect_setequal(aqi_color(20:30), rep("#00E400", 11))
})


test_that("aqi_descriptor() catches invalid inputs", {
  expect_error(aqi_descriptor(-1))
  expect_error(aqi_descriptor(501))
  expect_error(aqi_descriptor(NULL))
  expect_error(aqi_descriptor(NA_integer_))
  expect_error(aqi_descriptor(c()))
  expect_error(aqi_descriptor(20, 30, -1))
  expect_error(aqi_descriptor(20, 30, NULL))
})

test_that("aqi_descriptor() returns expected results", {
  expect_equal(aqi_descriptor(0), "Good")
  expect_equal(aqi_descriptor(0), aqi_descriptor(50))

  expect_equal(aqi_descriptor(51), "Moderate")
  expect_equal(aqi_descriptor(51), aqi_descriptor(100))

  expect_equal(aqi_descriptor(101), "Unhealthy for Sensitive Groups")
  expect_equal(aqi_descriptor(101), aqi_descriptor(150))

  expect_equal(aqi_descriptor(151), "Unhealthy")
  expect_equal(aqi_descriptor(151), aqi_descriptor(200))

  expect_equal(aqi_descriptor(201), "Very Unhealthy")
  expect_equal(aqi_descriptor(201), aqi_descriptor(300))

  expect_equal(aqi_descriptor(301), "Hazardous")
  expect_equal(aqi_descriptor(301), aqi_descriptor(500))

  expect_setequal(aqi_descriptor(20:30), rep("Good", 11))
})
