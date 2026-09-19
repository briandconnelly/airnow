key_pattern <- "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

test_that("fixtures record with the key redacted and replay without it", {
  httptest2::with_mock_dir("harness", {
    resp <- req_airnow() |>
      httr2::req_url_path_append("forecast", "current") |>
      httr2::req_url_query(
        zipCode = "90210",
        format = "application/json",
        api_key = get_airnow_key(ask = FALSE)
      ) |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 200)
  })

  files <- list.files(
    testthat::test_path("harness"),
    recursive = TRUE, full.names = TRUE
  )
  expect_true(length(files) >= 1)
  for (f in files) {
    text <- readLines(f, warn = FALSE)
    expect_false(
      any(grepl(key_pattern, text, ignore.case = TRUE)),
      info = f
    )
    expect_false(any(grepl("api_key=", text, fixed = TRUE)), info = f)
  }
})

test_that("every recorded fixture path fits the 100-byte tarball limit", {
  files <- list.files(
    testthat::test_path(),
    pattern = "\\.json$", recursive = TRUE, full.names = FALSE
  )
  files <- files[grepl("/an/", files, fixed = TRUE)]
  expect_true(length(files) > 0)
  tarball_paths <- file.path("airnow", "tests", "testthat", files)
  too_long <- tarball_paths[nchar(tarball_paths, type = "bytes") > 100]
  expect_length(too_long, 0)
})
