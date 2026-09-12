test_that("airnow_areas has the documented shape", {
  areas <- areas_table()
  expect_s3_class(areas, "tbl_df")
  expect_equal(nrow(areas), 1036)
  expect_named(areas, c(
    "reporting_area", "state_code", "country_code", "latitude", "longitude",
    "gmt_offset", "observes_dst", "tz_standard", "tz_daylight",
    "reporting_area_code", "agency", "lookup_behavior",
    "considered_monitors", "lookup_boundary"
  ))
  expect_type(areas$latitude, "double")
  expect_type(areas$longitude, "double")
  expect_type(areas$gmt_offset, "integer")
  expect_type(areas$observes_dst, "logical")
  expect_false(any(is.na(areas$reporting_area_code)))
  expect_equal(anyDuplicated(areas$reporting_area_code), 0)
  expect_true(all(grepl("^[a-z]{2}[0-9]{3}$", areas$reporting_area_code)))
})

test_that("airnow_areas has no carriage returns and preserves UTF-8", {
  areas <- areas_table()
  is_chr <- vapply(areas, is.character, logical(1))
  for (col in names(areas)[is_chr]) {
    expect_false(
      any(grepl("\r", areas[[col]], fixed = TRUE)),
      info = col
    )
  }
  guanajuato <- areas$agency[areas$reporting_area == "Guanajuato"]
  expect_equal(
    guanajuato,
    "Secretaría de Medio Ambiente y Ordenamiento Territorial"
  )
  expect_true(validUTF8(guanajuato))
})

test_that("airnow_areas contains known rows", {
  areas <- areas_table()

  napa <- areas[areas$reporting_area_code == "ca064", ]
  expect_equal(napa$reporting_area, "Napa")
  expect_equal(napa$state_code, "CA")

  phoenix <- areas[areas$reporting_area_code == "az001", ]
  expect_equal(phoenix$reporting_area, "Phoenix")
  expect_false(phoenix$observes_dst)
  expect_equal(phoenix$tz_standard, "MST")
  expect_equal(phoenix$gmt_offset, -7L)

  aberdeen <- areas[areas$reporting_area == "Aberdeen", ]
  expect_equal(nrow(aberdeen), 2)
  expect_setequal(aberdeen$state_code, c("SD", "WA"))

  expect_equal(sum(is.na(areas$lookup_boundary)), 68)
})

test_that("airnow_areas has the expected number of colliding names", {
  areas <- areas_table()
  colliding <- unique(areas$reporting_area[duplicated(areas$reporting_area)])
  expect_length(colliding, 26)
})

test_that("airnow_areas is reachable with the package namespace prefix", {
  expect_equal(nrow(airnow::airnow_areas), 1036)
})
