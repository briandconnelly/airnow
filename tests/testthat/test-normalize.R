test_that("to_parameter_factor() absorbs the API's spelling variants", {
  result <- to_parameter_factor(c("OZONE", "Ozone", "O3", "PM2.5", "PM10", "CO", "NO2", "SO2")) # nolint
  expect_s3_class(result, "factor")
  expect_false(is.ordered(result))
  expect_equal(levels(result), c("ozone", "pm2.5", "pm10", "co", "no2", "so2"))
  expect_equal(
    as.character(result),
    c("ozone", "ozone", "ozone", "pm2.5", "pm10", "co", "no2", "so2")
  )
})

test_that("to_parameter_factor() warns about unknown values instead of silently dropping them", { # nolint
  expect_warning(result <- to_parameter_factor(c("OZONE", "RADON")), "RADON")
  expect_equal(as.character(result), c("ozone", NA))
  expect_silent(to_parameter_factor(c("OZONE", NA)))
})

test_that("to_category_factor() is ordered by default and warns on unknowns", {
  result <- to_category_factor(c("Good", "Hazardous", "Unavailable"))
  expect_true(is.ordered(result))
  expect_equal(levels(result), category_levels)
  expect_equal(as.integer(result), c(1L, 6L, 7L))
  expect_true(result[1] < result[2])

  unordered <- to_category_factor("Good", ordered = FALSE)
  expect_false(is.ordered(unordered))

  expect_warning(
    result <- to_category_factor(c("Good", "Beyond Index")),
    "Beyond Index"
  )
  expect_equal(as.character(result), c("Good", NA))
})

test_that("hour_label_to_integer() parses HH:MM labels", {
  expect_equal(hour_label_to_integer(c("18:00", "00:00", "07:00")), c(18L, 0L, 7L)) # nolint
  expect_equal(hour_label_to_integer(NA_character_), NA_integer_)
  expect_silent(hour_label_to_integer(c("18:00", NA)))
  expect_warning(result <- hour_label_to_integer(c("18:00", "6pm")), "6pm")
  expect_equal(result, c(18L, NA))
  expect_equal(hour_label_to_integer(character(0)), integer(0))
})

test_that("derive_utc_datetime() applies the area's offset and DST rule", {
  # Napa (ca064): gmt_offset -8, observes DST, PST/PDT
  # 2026-09-09 18:00 PDT == 2026-09-10 01:00 UTC
  result <- derive_utc_datetime(
    date = as.Date("2026-09-09"), hour = 18L,
    tz_abbr = "PDT", reporting_area_code = "ca064"
  )
  expect_s3_class(result, "POSIXct")
  expect_equal(attr(result, "tzone"), "UTC")
  expect_equal(result, as.POSIXct("2026-09-10 01:00:00", tz = "UTC"))

  # Same clock time in standard time is one hour later in UTC
  result <- derive_utc_datetime(as.Date("2026-01-09"), 18L, "PST", "ca064")
  expect_equal(result, as.POSIXct("2026-01-10 02:00:00", tz = "UTC"))

  # Phoenix (az001): gmt_offset -7, no DST
  result <- derive_utc_datetime(as.Date("2026-07-01"), 12L, "MST", "az001")
  expect_equal(result, as.POSIXct("2026-07-01 19:00:00", tz = "UTC"))

  # Midnight label stays on the API's date
  result <- derive_utc_datetime(as.Date("2026-09-10"), 0L, "PDT", "ca064")
  expect_equal(result, as.POSIXct("2026-09-10 07:00:00", tz = "UTC"))
})

test_that("derive_utc_datetime() is NA-safe and warns on unmatched zones", {
  # Unknown abbreviation for the area: NA with a warning, never a guess
  expect_warning(
    result <- derive_utc_datetime(as.Date("2026-09-09"), 18L, "XYZ", "ca064"),
    "XYZ"
  )
  expect_true(is.na(result))

  # Unknown area code: NA, no warning here (the join already warned)
  expect_silent(
    result <- derive_utc_datetime(as.Date("2026-09-09"), 18L, "PDT", "zz999")
  )
  expect_true(is.na(result))

  # Missing pieces propagate
  expect_true(is.na(derive_utc_datetime(as.Date(NA), 18L, "PDT", "ca064")))
  expect_true(is.na(derive_utc_datetime(as.Date("2026-09-09"), NA_integer_, "PDT", "ca064"))) # nolint
  expect_true(is.na(derive_utc_datetime(as.Date("2026-09-09"), 18L, NA, "ca064"))) # nolint

  # Vectorised, mixed
  result <- derive_utc_datetime(
    as.Date(c("2026-09-09", "2026-09-09")), c(18L, 18L),
    c("PDT", "PDT"), c("ca064", "zz999")
  )
  expect_equal(is.na(result), c(FALSE, TRUE))
})
