test_that("aqi_color() rejects non-numeric input", {
  expect_error(aqi_color(NULL))
  expect_error(aqi_color(c()))
  expect_error(aqi_color("35"))
  expect_error(aqi_color(1.5))
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

test_that("aqi_color() clamps values above 500 to Hazardous", {
  expect_equal(aqi_color(501), "#7E0023")
  expect_equal(aqi_color(874), "#7E0023")
})

test_that("aqi_color() passes NA through silently", {
  expect_silent(result <- aqi_color(NA_integer_))
  expect_equal(result, NA_character_)
  expect_silent(result <- aqi_color(NA))
  expect_equal(result, NA_character_)
  expect_equal(aqi_color(c(10, NA, 600)), c("#00E400", NA, "#7E0023"))
})

test_that("aqi_color() warns on negative values and returns NA", {
  expect_warning(result <- aqi_color(-1), "-1")
  expect_equal(result, NA_character_)
  expect_warning(result <- aqi_color(c(35, -5)), "negative")
  expect_equal(result, c("#00E400", NA))
})


test_that("aqi_descriptor() rejects non-numeric input", {
  expect_error(aqi_descriptor(NULL))
  expect_error(aqi_descriptor(c()))
  expect_error(aqi_descriptor("35"))
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

test_that("aqi_descriptor() clamps, passes NA, and warns on negatives", {
  expect_equal(aqi_descriptor(874), "Hazardous")
  expect_silent(result <- aqi_descriptor(NA_integer_))
  expect_equal(result, NA_character_)
  expect_warning(result <- aqi_descriptor(-1))
  expect_equal(result, NA_character_)
})
