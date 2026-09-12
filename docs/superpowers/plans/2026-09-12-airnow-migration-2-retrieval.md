# AirNow API Migration, Plan 2 of 2: Retrieval Functions and Compatibility

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship airnow 0.2.0: new retrieval functions on the 2026 AirNow web services, deprecated shims that keep `get_airnow_conditions()`, `get_airnow_forecast()`, and `get_airnow_area()` working with their old column contracts, recorded test fixtures, and updated documentation, before the old services retire on 2026-09-30.

**Architecture:** Every retrieval function is a thin request builder around `req_airnow()` plus `perform_airnow()` from Plan 1, followed by a pure "finish" function that normalizes columns. The finish functions are unit-tested with literal tibbles (no network); the end-to-end column contracts are tested against httptest2 recordings. Compatibility shims call the new functions and then apply a pure legacy transform. Area geography comes from the bundled `airnow_areas` table via `areas_table()`, with one memoised API call only for zip codes whose reporting-area name is ambiguous.

**Tech Stack:** R (>= 4.1), httr2, jsonlite, tibble, cli, rlang, lifecycle, testthat 3e (with `local_mocked_bindings()`), httptest2 1.2.x, devtools/roxygen2.

**Spec:** `docs/superpowers/specs/2026-09-09-airnow-api-migration-design.md`. This plan implements sections 4, 5, 6 ("`resolve_area_code()`", "Rate-limit budget"), 7, and the phase 1 list in section 10. Plan 1 (`2026-09-12-airnow-migration-1-foundation.md`) must be complete first; this plan uses its interfaces without redefining them.

## Global Constraints

- Repository root is `/Users/bdc/projects/airnow`. Run every command from there.
- Everything in Plan 1's Global Constraints applies here too (cli/rlang conventions, 80-column lines or `# nolint`, conventional commits with the attribution footer, `devtools::document()` after roxygen changes, never report a check you did not run).
- **The API key.** The real key is in the shell variable `AIRNOW_API_TOKEN` (not `AIRNOW_API_KEY`). It is a 36-character UUID. Never print it, never commit it, never put it in a test file. Steps that record fixtures prefix the command with `AIRNOW_API_KEY="$AIRNOW_API_TOKEN"`. Steps that replay fixtures use `AIRNOW_API_KEY=test-key`, which proves no live request is made.
- **httptest2 facts (verified against version 1.2.2, the installed version).** `with_mock_dir("name", expr)` records to `tests/testthat/name/` when that directory does not exist and replays from it when it does. The mock file path is `<host>/<path>-<6-char hash of the query string>.json`, and the redactor is applied to the *request* before hashing on both record and replay, so a redactor that rewrites `api_key=...` in the URL makes the path independent of the key. The package-level redactor is a file `inst/httptest2/redact.R` that evaluates to a single function. `httptest2::without_internet(expr)` makes any live request error.
- **Interfaces from Plan 1 that this plan calls** (do not re-implement them): `req_airnow()`, `perform_airnow(req)`, `get_airnow_key(ask)`, `areas_table()`, `parameter_levels`, `category_levels`, `to_parameter_factor(x)`, `to_category_factor(x, ordered)`, `hour_label_to_integer(x)`, `derive_utc_datetime(date, hour, tz_abbr, reporting_area_code)`, `clean_names(x)`, `check_location(zip, latitude, longitude)`, `check_distance(distance)`, `check_bounding_box(box)`, `check_aqi(x)`.
- **Verified API facts (2026-09-09 and 2026-09-12).** Base `https://www.airnowapi.org/aq`. Key parameter `api_key` everywhere. Paths are case-insensitive and trailing slashes do not matter. `forecast/current` accepts `zipCode`, `latitude`+`longitude`, or `reportingAreaCode`. `forecast/historical` accepts `reportingAreaCode`, `startDate`, `endDate`, optional `forecastRange` and `parameter` (values like `PM2.5`, `OZONE`). `observation/current/ziplatLong` accepts `zipCode` or `latitude`+`longitude`; `observation/current/racode` accepts `reportingAreaCode`. `distance` is ignored by all new services. Field names are lowerCamelCase. "No data" is a 200 with a `WebServiceError` body, which `perform_airnow()` turns into a zero-column tibble.
- **Recording etiquette.** Each recording step makes a handful of live requests against a 500/hour budget. Record once; do not loop.

---

### Task 1: httptest2 harness

Implements spec section 7 ("Recorded fixtures", "A redactor is mandatory"). Everything later in this plan records through this harness.

**Files:**
- Modify: `DESCRIPTION` (Suggests)
- Create: `inst/httptest2/redact.R`
- Create: `tests/testthat/setup.R`
- Create: `tests/testthat/helper-cache.R`
- Create: `tests/testthat/test-harness.R`
- Create: `tests/testthat/harness/` (recorded)
- Modify: `.github/workflows/R-CMD-check.yaml`

**Interfaces:**
- Produces: a working `httptest2::with_mock_dir()` setup in which recorded URLs never contain the key and replay works under any key value.
- Produces: `local_area_code_cache()` test helper (used from Task 2 on) that empties the session memo and restores it afterwards.

- [ ] **Step 1: Add httptest2 to Suggests**

Run:
```bash
Rscript -e 'usethis::use_package("httptest2", type = "Suggests")'
grep -n "httptest2" DESCRIPTION
```
Expected: one line `    httptest2,` inside the `Suggests:` block.

- [ ] **Step 2: Write the redactor**

Create `inst/httptest2/redact.R` containing exactly one function expression (httptest2 sources the file and uses its value):

```r
function(resp) {
  # Applied by httptest2 to both requests (when computing the mock file
  # path) and responses (when writing the file). Replacing the key in the URL
  # makes the fixture path independent of whichever key made the request and
  # keeps the key out of the recorded file.
  httptest2::gsub_response(resp, "api_key=[^&]+", "api_key=REDACTED")
}
```

- [ ] **Step 3: Write the test setup and the cache helper**

Create `tests/testthat/setup.R`:

```r
# Tests replay recorded fixtures, so they never need a real key. Provide a
# placeholder when none is set so credential checks pass on CI, CRAN, and
# contributors' machines. When a real key IS set (locally, for recording),
# leave it alone.
if (!nzchar(Sys.getenv("AIRNOW_API_KEY"))) {
  withr::local_envvar(
    AIRNOW_API_KEY = "test-key",
    .local_envir = testthat::teardown_env()
  )
}
```

Create `tests/testthat/helper-cache.R`:

```r
# Empty the session-level area-code memo for the duration of a test and
# restore it afterwards. `the` is defined in R/areas.R (Task 2); before that
# file exists this helper is simply unused.
local_area_code_cache <- function(env = parent.frame()) {
  old <- the$area_codes
  the$area_codes <- list()
  withr::defer(the$area_codes <- old, envir = env)
}
```

- [ ] **Step 4: Write the harness test**

Create `tests/testthat/test-harness.R`:

```r
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
```

- [ ] **Step 5: Record the fixture**

Run:
```bash
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "harness")'
find tests/testthat/harness -type f
```
Expected: `FAIL 0`. `find` lists one file like `tests/testthat/harness/www.airnowapi.org/aq/forecast/current-XXXXXX.json`.

- [ ] **Step 6: Prove the recording is clean and replays without the key**

Run:
```bash
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "harness")'
```
Expected: `no key in tests/`, then `FAIL 0` a second time. If the second run fails with `Request URL not found in mock files`, the redactor did not apply to the request path; check that `inst/httptest2/redact.R` contains only the function and re-run Step 5 after deleting `tests/testthat/harness/`.

- [ ] **Step 7: Add the CI leak scan**

In `.github/workflows/R-CMD-check.yaml`, insert this step directly after the `- uses: actions/checkout@v3` line (keep indentation at six spaces, matching the surrounding steps):

```yaml
      - name: Fail if an API key is present in recorded fixtures
        shell: bash
        run: |
          pattern='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
          if grep -rliE "$pattern" tests/testthat --include='*.json' --include='*.R' --exclude='test-*.R' --exclude='helper-*.R' --exclude='setup.R'; then
            echo "::error::Key-shaped string found in test fixtures"; exit 1
          fi
          if [ -n "$AIRNOW_API_KEY" ] && grep -rlF "$AIRNOW_API_KEY" tests/testthat; then
            echo "::error::The AIRNOW_API_KEY secret is present in tests/"; exit 1
          fi
```

Then run the same scan locally to make sure it passes with the current tree:
```bash
pattern='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
grep -rliE "$pattern" tests/testthat --include='*.json' --include='*.R' --exclude='test-*.R' --exclude='helper-*.R' --exclude='setup.R' || echo "scan clean"
```
Expected: `scan clean`. (`test-credentials.R` contains a fake UUID on purpose; the excludes skip test files.)

- [ ] **Step 8: Commit**

```bash
git add DESCRIPTION inst/httptest2/redact.R tests/testthat/setup.R \
  tests/testthat/helper-cache.R tests/testthat/test-harness.R \
  tests/testthat/harness .github/workflows/R-CMD-check.yaml
git commit -m "$(cat <<'EOF'
test: add httptest2 harness with key redaction and a CI fixture leak scan

Recorded URLs never contain api_key, so fixtures replay under any key and
the raw key cannot reach git or the CRAN tarball.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 2: Reporting-area resolution and joins

Implements spec section 6 ("`resolve_area_code()`", "Rate-limit budget") and the join rules in sections 4.2, 5.1, and 7 ("A join miss", "A colliding name").

**Files:**
- Create: `R/areas.R`
- Create: `tests/testthat/test-areas.R`
- Create: `tests/testthat/resolve_zip/` (recorded)

**Interfaces:**
- Produces: `the`, an environment holding `the$area_codes` (a named list memo).
- Produces: `resolve_area_code(zip = NULL, latitude = NULL, longitude = NULL, api_key = get_airnow_key())` returns one area code string such as `"ca132"` by calling `forecast/current`, memoised per location for the session. Aborts with a clear message if the API reports no reporting area.
- Produces: `join_areas_by_name(x, zip = NULL, latitude = NULL, longitude = NULL, api_key = get_airnow_key())` takes a tibble with a character `reportingAreaName` column and adds `reportingAreaCode`, `stateCode`, `latitude`, `longitude`, `reportingAreaAgency`. Ambiguous names are resolved offline by nearest neighbour for coordinate queries and via `resolve_area_code()` for zip queries. A name absent from the table warns and leaves those five columns `NA`.
- Produces: `join_areas_by_code(x)` takes a tibble with `reportingAreaCode` and fills `latitude` and `longitude` from the table, plus `stateCode` where it is missing or `NA`. Unknown codes warn and leave `NA`.
- Produces: `lookup_areas_by_name(name)` and `nearest_area(latitude, longitude, candidates)` (small helpers, also tested).

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-areas.R`:

```r
test_that("lookup_areas_by_name() returns zero, one, or many rows", {
  expect_equal(nrow(lookup_areas_by_name("Napa")), 1)
  expect_equal(nrow(lookup_areas_by_name("Aberdeen")), 2)
  expect_equal(nrow(lookup_areas_by_name("Atlantis")), 0)
})

test_that("nearest_area() picks the closest candidate", {
  candidates <- lookup_areas_by_name("Aberdeen")
  # Near Aberdeen, WA
  expect_equal(nearest_area(47.1, -123.8, candidates)$reporting_area_code, "wa008") # nolint
  # Near Aberdeen, SD
  expect_equal(nearest_area(45.5, -98.5, candidates)$reporting_area_code, "sd009") # nolint
})

test_that("resolve_area_code() resolves a zip through the API and memoises", {
  local_area_code_cache()

  httptest2::with_mock_dir("resolve_zip", {
    expect_equal(resolve_area_code(zip = "90210"), "ca132")
  })

  # Second call must come from the memo: any request now is an error
  httptest2::without_internet({
    expect_equal(resolve_area_code(zip = "90210"), "ca132")
  })
  expect_named(the$area_codes, "zip:90210")
})

test_that("resolve_area_code() aborts when the API finds no area", {
  local_area_code_cache()
  testthat::local_mocked_bindings(
    perform_airnow = function(req) tibble::tibble()
  )
  expect_error(
    resolve_area_code(latitude = 39.5, longitude = -116.9),
    "No AirNow reporting area"
  )
})

test_that("resolve_area_code() validates its location like check_location()", {
  expect_error(resolve_area_code())
  expect_error(resolve_area_code(zip = "1234"))
  expect_error(resolve_area_code(latitude = 91, longitude = 0))
})

test_that("join_areas_by_name() fills geography for an unambiguous name", {
  x <- tibble::tibble(
    reportingAreaName = c("Napa", "Napa"),
    parameterName = c("OZONE", "PM2.5")
  )
  result <- httptest2::without_internet(
    join_areas_by_name(x, latitude = 38.3, longitude = -122.3)
  )
  expect_equal(result$reportingAreaCode, c("ca064", "ca064"))
  expect_equal(result$stateCode, c("CA", "CA"))
  expect_equal(result$reportingAreaAgency, rep("Bay Area Air District", 2))
  expect_type(result$latitude, "double")
  expect_false(anyNA(result$latitude))
})

test_that("join_areas_by_name() resolves colliding names offline for coordinates", { # nolint
  x <- tibble::tibble(reportingAreaName = "Aberdeen")
  result <- httptest2::without_internet(
    join_areas_by_name(x, latitude = 47.1, longitude = -123.8)
  )
  expect_equal(result$reportingAreaCode, "wa008")
  expect_equal(result$stateCode, "WA")
})

test_that("join_areas_by_name() resolves colliding names via the API for zips", { # nolint
  local_area_code_cache()
  calls <- 0
  testthat::local_mocked_bindings(
    resolve_area_code = function(...) {
      calls <<- calls + 1
      "sd009"
    }
  )
  x <- tibble::tibble(reportingAreaName = c("Aberdeen", "Aberdeen"))
  result <- join_areas_by_name(x, zip = "57401")
  expect_equal(result$reportingAreaCode, c("sd009", "sd009"))
  expect_equal(result$stateCode, c("SD", "SD"))
  expect_equal(calls, 1)
})

test_that("join_areas_by_name() warns and leaves NA on a miss", {
  x <- tibble::tibble(reportingAreaName = c("Atlantis", "Napa"))
  expect_warning(
    result <- join_areas_by_name(x, zip = "90210"),
    "Atlantis"
  )
  expect_equal(result$reportingAreaCode, c(NA, "ca064"))
  expect_equal(result$stateCode, c(NA, "CA"))
  expect_true(is.na(result$latitude[1]))
  expect_equal(nrow(result), 2)
})

test_that("join_areas_by_name() handles zero rows", {
  x <- tibble::tibble(reportingAreaName = character(0))
  result <- join_areas_by_name(x, zip = "90210")
  expect_equal(nrow(result), 0)
  expect_true(all(c("reportingAreaCode", "stateCode", "latitude", "longitude", "reportingAreaAgency") %in% names(result))) # nolint
})

test_that("join_areas_by_code() fills coordinates and missing state codes", {
  x <- tibble::tibble(
    reportingAreaCode = c("ca064", "ca132", "zz999"),
    stateCode = c("CA", NA, NA)
  )
  expect_warning(result <- join_areas_by_code(x), "zz999")
  expect_equal(result$stateCode, c("CA", "CA", NA))
  expect_equal(is.na(result$latitude), c(FALSE, FALSE, TRUE))

  no_state <- tibble::tibble(reportingAreaCode = "ca064")
  result <- join_areas_by_code(no_state)
  expect_equal(result$stateCode, "CA")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "areas")'`
Expected: failures with `could not find function "lookup_areas_by_name"` (and the helper's reference to `the` erroring).

- [ ] **Step 3: Implement `R/areas.R`**

```r
# Session-level state. `area_codes` memoises location -> reporting area code
# so a loop over the same location costs one request, not one per call.
the <- new.env(parent = emptyenv())
the$area_codes <- list()


#' Rows of `airnow_areas` with the given reporting-area name
#' @param name A single area name as the API returns it
#' @return A tibble with 0, 1, or several rows
#' @noRd
lookup_areas_by_name <- function(name) {
  areas <- areas_table()
  areas[!is.na(areas$reporting_area) & areas$reporting_area == name, , drop = FALSE] # nolint
}


#' Great-circle distance in kilometres
#' @noRd
haversine_km <- function(lat1, lon1, lat2, lon2) {
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 +
    cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  2 * 6371 * asin(pmin(1, sqrt(a)))
}


#' The candidate row closest to a point
#' @param latitude,longitude Query point in decimal degrees
#' @param candidates A subset of `airnow_areas` with at least one row
#' @return A one-row tibble
#' @noRd
nearest_area <- function(latitude, longitude, candidates) {
  d <- haversine_km(latitude, longitude, candidates$latitude, candidates$longitude) # nolint
  candidates[which.min(d), , drop = FALSE]
}


#' Resolve a zip code or coordinate pair to a reporting-area code
#'
#' Uses `/forecast/current/`, which returns `reportingAreaCode` for both
#' input types (spec section 2.3). Results are memoised in `the$area_codes`
#' for the session.
#'
#' @inheritParams get_airnow_observations
#' @return A single area code such as `"ca132"`
#' @noRd
resolve_area_code <- function(zip = NULL,
                              latitude = NULL,
                              longitude = NULL,
                              api_key = get_airnow_key()) {
  location <- check_location(zip, latitude, longitude)

  memo_key <- if (location$type == "zipCode") {
    paste0("zip:", location$zip)
  } else {
    paste0("latlong:", location$latitude, ",", location$longitude)
  }

  cached <- the$area_codes[[memo_key]]
  if (!is.null(cached)) {
    return(cached)
  }

  result <- req_airnow() |>
    httr2::req_url_path_append("forecast", "current") |>
    httr2::req_url_query(
      zipCode = location$zip,
      latitude = location$latitude,
      longitude = location$longitude,
      format = "application/json",
      api_key = api_key
    ) |>
    perform_airnow()

  if (nrow(result) == 0 || !("reportingAreaCode" %in% names(result))) {
    cli::cli_abort("No AirNow reporting area was found for the given location") # nolint
  }

  code <- as.character(result$reportingAreaCode[[1]])
  the$area_codes[[memo_key]] <- code
  code
}


# Columns added by join_areas_by_name(), with their NA of the right type
area_join_defaults <- list(
  reportingAreaCode = NA_character_,
  stateCode = NA_character_,
  latitude = NA_real_,
  longitude = NA_real_,
  reportingAreaAgency = NA_character_
)


#' Add reporting-area geography to rows that only carry an area name
#'
#' The `/ziplatLong` service returns `reportingAreaName` but no code or
#' state, and 26 names appear in more than one state. Unambiguous names are
#' joined offline. Ambiguous names are resolved offline by nearest neighbour
#' when the query was a coordinate pair, and via one memoised API call when
#' the query was a zip code. Names missing from the table warn and stay NA.
#'
#' @param x A tibble with a character column `reportingAreaName`
#' @param zip,latitude,longitude The original query (one form or the other)
#' @param api_key API key, only used for the ambiguous-zip case
#' @return `x` with the five columns in `area_join_defaults` added
#' @noRd
join_areas_by_name <- function(x,
                               zip = NULL,
                               latitude = NULL,
                               longitude = NULL,
                               api_key = get_airnow_key()) {
  n <- nrow(x)
  for (col in names(area_join_defaults)) {
    x[[col]] <- rep(area_join_defaults[[col]], n)
  }
  if (n == 0) {
    return(x)
  }

  misses <- character(0)
  for (name in unique(x$reportingAreaName)) {
    candidates <- lookup_areas_by_name(name)
    row <- NULL

    if (nrow(candidates) == 1) {
      row <- candidates
    } else if (nrow(candidates) > 1) {
      if (!is.null(zip)) {
        code <- resolve_area_code(zip = zip, api_key = api_key)
        row <- candidates[candidates$reporting_area_code == code, , drop = FALSE] # nolint
      } else {
        row <- nearest_area(latitude, longitude, candidates)
      }
    }

    if (is.null(row) || nrow(row) != 1) {
      misses <- c(misses, name)
      next
    }

    sel <- !is.na(x$reportingAreaName) & x$reportingAreaName == name
    x$reportingAreaCode[sel] <- row$reporting_area_code
    x$stateCode[sel] <- row$state_code
    x$latitude[sel] <- row$latitude
    x$longitude[sel] <- row$longitude
    x$reportingAreaAgency[sel] <- row$agency
  }

  if (length(misses) > 0) {
    cli::cli_warn(c(
      "Reporting area{?s} {.val {misses}} not found in {.field airnow_areas}; geography columns will be {.val NA}", # nolint
      "i" = "AirNow adds, renames, and retires areas; the bundled table may be stale." # nolint
    ))
  }
  x
}


#' Add coordinates (and a missing state code) to rows that carry an area code
#'
#' @param x A tibble with a character column `reportingAreaCode`
#' @return `x` with `latitude`, `longitude`, and `stateCode` filled
#' @noRd
join_areas_by_code <- function(x) {
  areas <- areas_table()
  idx <- match(x$reportingAreaCode, areas$reporting_area_code)

  unknown <- unique(x$reportingAreaCode[is.na(idx) & !is.na(x$reportingAreaCode)]) # nolint
  if (length(unknown) > 0) {
    cli::cli_warn("Reporting area code{?s} {.val {unknown}} not found in {.field airnow_areas}; geography columns will be {.val NA}") # nolint
  }

  x$latitude <- areas$latitude[idx]
  x$longitude <- areas$longitude[idx]

  if (!("stateCode" %in% names(x))) {
    x$stateCode <- rep(NA_character_, nrow(x))
  }
  fill <- is.na(x$stateCode)
  x$stateCode[fill] <- areas$state_code[idx][fill]
  x
}
```

- [ ] **Step 4: Record the one fixture and run the tests**

Run:
```bash
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "areas")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "areas")'
```
Expected: `FAIL 0` both times, `no key in tests/`, and a new file under `tests/testthat/resolve_zip/www.airnowapi.org/aq/forecast/`.

- [ ] **Step 5: Commit**

```bash
git add R/areas.R tests/testthat/test-areas.R tests/testthat/resolve_zip
git commit -m "$(cat <<'EOF'
feat: resolve reporting-area codes and join airnow_areas geography

Unambiguous names join offline; colliding names use nearest-neighbour for
coordinate queries and one memoised forecast/current request for zips.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 3: `get_airnow_reporting_area()`

Implements spec section 4.1 (the renamed area-lookup function; section 8 question 1).

**Files:**
- Create: `R/get_airnow_reporting_area.R`
- Create: `tests/testthat/test-get_airnow_reporting_area.R`
- Create: `tests/testthat/reporting_area/` (recorded)

**Interfaces:**
- Produces: exported `get_airnow_reporting_area(zip = NULL, latitude = NULL, longitude = NULL, api_key = get_airnow_key())` returning a one-row tibble with columns `reporting_area_code`, `reporting_area`, `state_code`, `latitude`, `longitude`.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-get_airnow_reporting_area.R`:

```r
test_that("get_airnow_reporting_area() validates its location", {
  expect_error(get_airnow_reporting_area())
  expect_error(get_airnow_reporting_area(zip = "1234"))
  expect_error(get_airnow_reporting_area(latitude = 91, longitude = 0))
  expect_error(get_airnow_reporting_area(latitude = 0))
})

test_that("get_airnow_reporting_area() returns one row for a zip", {
  local_area_code_cache()
  httptest2::with_mock_dir("reporting_area", {
    result <- get_airnow_reporting_area(zip = "90210")
  })
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_named(result, c(
    "reporting_area_code", "reporting_area", "state_code",
    "latitude", "longitude"
  ))
  expect_equal(result$reporting_area_code, "ca132")
  expect_equal(result$reporting_area, "NW Coastal LA")
  expect_equal(result$state_code, "CA")
})

test_that("get_airnow_reporting_area() warns when the code is not in the table", { # nolint
  local_area_code_cache()
  testthat::local_mocked_bindings(resolve_area_code = function(...) "zz999")
  expect_warning(result <- get_airnow_reporting_area(zip = "90210"), "zz999")
  expect_equal(result$reporting_area_code, "zz999")
  expect_true(is.na(result$reporting_area))
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "reporting_area")'`
Expected: `could not find function "get_airnow_reporting_area"`.

- [ ] **Step 3: Implement**

Create `R/get_airnow_reporting_area.R`:

```r
#' Find the AirNow reporting area for a location
#'
#' `get_airnow_reporting_area()` looks up which AirNow reporting area serves
#' a ZIP code or a latitude/longitude pair. The returned
#' `reporting_area_code` is the `area` argument for
#' [get_airnow_observations()], [get_airnow_forecasts()], and
#' [get_airnow_forecast_history()].
#'
#' This makes one API request per distinct location per session; results
#' are cached in memory.
#'
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param api_key AirNow API key
#'
#' @return A one-row tibble with columns `reporting_area_code`,
#'   `reporting_area`, `state_code`, `latitude`, and `longitude`.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_reporting_area(zip = "90210")
#' get_airnow_reporting_area(latitude = 38.3191, longitude = -122.2998)
#' }
get_airnow_reporting_area <- function(zip = NULL,
                                      latitude = NULL,
                                      longitude = NULL,
                                      api_key = get_airnow_key()) {
  code <- resolve_area_code(
    zip = zip, latitude = latitude, longitude = longitude, api_key = api_key
  )

  areas <- areas_table()
  area <- areas[areas$reporting_area_code == code, , drop = FALSE]

  if (nrow(area) != 1) {
    cli::cli_warn("Reporting area code {.val {code}} not found in {.field airnow_areas}; returning the code only") # nolint
    return(tibble::tibble(
      reporting_area_code = code,
      reporting_area = NA_character_,
      state_code = NA_character_,
      latitude = NA_real_,
      longitude = NA_real_
    ))
  }

  area[, c("reporting_area_code", "reporting_area", "state_code", "latitude", "longitude")] # nolint
}
```

- [ ] **Step 4: Document, record, verify**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "reporting_area")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "reporting_area")'
grep -n "get_airnow_reporting_area" NAMESPACE
```
Expected: `FAIL 0` twice, `no key in tests/`, and `export(get_airnow_reporting_area)`.

- [ ] **Step 5: Commit**

```bash
git add R/get_airnow_reporting_area.R NAMESPACE man/ \
  tests/testthat/test-get_airnow_reporting_area.R tests/testthat/reporting_area
git commit -m "$(cat <<'EOF'
feat: add get_airnow_reporting_area()

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 4: Shared argument checks, column helpers, and `get_airnow_forecasts()`

Implements spec sections 4.1 and 4.3 for the current-forecast service.

**Files:**
- Modify: `R/argument_checks.R` (append three functions)
- Modify: `R/utils.R` (append two functions)
- Create: `R/get_airnow_forecasts.R`
- Create: `tests/testthat/test-get_airnow_forecasts.R`
- Modify: `tests/testthat/test-argument_checks.R` (append)
- Modify: `tests/testthat/test-utils.R` (append)
- Create: `tests/testthat/forecasts/` (recorded)

**Interfaces:**
- Produces: `check_clean_names(x)` aborts unless `x` is a single non-`NA` logical.
- Produces: `check_area_code(x)` aborts unless `x` is a string matching `^[a-z]{2}[0-9]{3}$` after lowercasing; returns the lowercased code.
- Produces: `check_area_or_location(zip, latitude, longitude, area)` returns a list with `type` (`"zipCode"`, `"latLong"`, or `"area"`), `zip`, `latitude`, `longitude`, `area`. Warns and drops the location when `area` is given alongside it.
- Produces: `add_missing_columns(x, defaults)` where `defaults` is a named list of typed `NA` values: adds absent columns and reorders so `names(defaults)` come first, extras after. Works on a 0x0 tibble.
- Produces: `forecast_columns` (the typed-NA defaults for the forecast contract) and `finish_forecast(x, clean_names)`, shared with Task 5.
- Produces: exported `get_airnow_forecasts(zip, latitude, longitude, area, clean_names = TRUE, api_key)`. Column contract with `clean_names = TRUE`, in order: `date_issue`, `date_valid`, `reporting_area`, `reporting_area_code`, `state_code`, `latitude`, `longitude`, `parameter`, `aqi`, `category_number`, `category_name`, `action_day`, `discussion`, `forecast_agency`. With `clean_names = FALSE`: `dateIssue`, `dateValid`, `reportingArea`, `reportingAreaCode`, `stateCode`, `latitude`, `longitude`, `parameterName`, `aqi`, `categoryNumber`, `categoryName`, `actionDay`, `discussion`, `forecastAgency`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-argument_checks.R`:

```r
test_that("check_clean_names() accepts only a single TRUE/FALSE", {
  expect_equal(check_clean_names(TRUE), TRUE)
  expect_equal(check_clean_names(FALSE), FALSE)
  expect_error(check_clean_names(NULL))
  expect_error(check_clean_names(NA))
  expect_error(check_clean_names(1))
  expect_error(check_clean_names(c(TRUE, FALSE)))
})

test_that("check_area_code() validates and lowercases", {
  expect_equal(check_area_code("ca064"), "ca064")
  expect_equal(check_area_code("CA064"), "ca064")
  expect_error(check_area_code("ca64"))
  expect_error(check_area_code("Napa"))
  expect_error(check_area_code(NULL))
  expect_error(check_area_code(NA_character_))
  expect_error(check_area_code(c("ca064", "ca132")))
})

test_that("check_area_or_location() prefers area and warns about extras", {
  result <- check_area_or_location(NULL, NULL, NULL, "ca064")
  expect_equal(result$type, "area")
  expect_equal(result$area, "ca064")
  expect_null(result$zip)

  expect_warning(
    result <- check_area_or_location("90210", NULL, NULL, "ca064"),
    "Ignoring"
  )
  expect_equal(result$type, "area")
  expect_null(result$zip)

  result <- check_area_or_location("90210", NULL, NULL, NULL)
  expect_equal(result$type, "zipCode")
  expect_null(result$area)

  result <- check_area_or_location(NULL, 38.3, -122.3, NULL)
  expect_equal(result$type, "latLong")

  expect_error(check_area_or_location(NULL, NULL, NULL, NULL))
})
```

Append to `tests/testthat/test-utils.R`:

```r
test_that("add_missing_columns() adds typed NA columns and orders them", {
  defaults <- list(a = NA_integer_, b = NA_character_, c = as.Date(NA))
  x <- tibble::tibble(b = c("x", "y"), extra = 1:2)
  result <- add_missing_columns(x, defaults)
  expect_named(result, c("a", "b", "c", "extra"))
  expect_type(result$a, "integer")
  expect_s3_class(result$c, "Date")
  expect_equal(nrow(result), 2)

  empty <- add_missing_columns(tibble::tibble(), defaults)
  expect_named(empty, c("a", "b", "c"))
  expect_equal(nrow(empty), 0)
  expect_type(empty$b, "character")
})
```

Create `tests/testthat/test-get_airnow_forecasts.R`:

```r
forecast_clean_names <- c(
  "date_issue", "date_valid", "reporting_area", "reporting_area_code",
  "state_code", "latitude", "longitude", "parameter", "aqi",
  "category_number", "category_name", "action_day", "discussion",
  "forecast_agency"
)
forecast_raw_names <- c(
  "dateIssue", "dateValid", "reportingArea", "reportingAreaCode",
  "stateCode", "latitude", "longitude", "parameterName", "aqi",
  "categoryNumber", "categoryName", "actionDay", "discussion",
  "forecastAgency"
)

test_that("get_airnow_forecasts() validates inputs", {
  expect_error(get_airnow_forecasts())
  expect_error(get_airnow_forecasts(zip = "1234"))
  expect_error(get_airnow_forecasts(latitude = 91, longitude = 0))
  expect_error(get_airnow_forecasts(area = "Napa"))
  expect_error(get_airnow_forecasts(zip = "90210", clean_names = NA))
  expect_error(get_airnow_forecasts(zip = "90210", clean_names = "yes"))
})

test_that("finish_forecast() normalizes a raw payload", {
  raw <- tibble::tibble(
    dateIssue = "2026-09-08", dateValid = "2026-09-09",
    reportingArea = "NW Coastal LA", reportingAreaCode = "ca132",
    stateCode = "CA", parameterName = c("PM2.5", "OZONE"), aqi = c(53L, 34L),
    forecastAgency = "South Coast AQMD", categoryNumber = c(2L, 1L),
    categoryName = c("Moderate", "Good"), actionDay = FALSE, discussion = ""
  )
  result <- finish_forecast(raw, clean_names = TRUE)
  expect_named(result, forecast_clean_names)
  expect_s3_class(result$date_issue, "Date")
  expect_s3_class(result$date_valid, "Date")
  expect_equal(as.character(result$parameter), c("pm2.5", "ozone"))
  expect_true(is.ordered(result$category_name))
  expect_equal(as.character(result$category_name), c("Moderate", "Good"))
  expect_type(result$aqi, "integer")
  expect_type(result$category_number, "integer")
  expect_type(result$action_day, "logical")
  expect_false(anyNA(result$latitude))

  raw_out <- finish_forecast(raw, clean_names = FALSE)
  expect_named(raw_out, forecast_raw_names)
})

test_that("finish_forecast() returns the full contract for zero rows", {
  result <- finish_forecast(tibble::tibble(), clean_names = TRUE)
  expect_named(result, forecast_clean_names)
  expect_equal(nrow(result), 0)
  expect_s3_class(result$date_valid, "Date")
})

test_that("finish_forecast() fills forecastAgency when the service omits it", {
  raw <- tibble::tibble(
    dateIssue = "2026-01-12", dateValid = "2026-01-13",
    reportingArea = "Northeast Maryland", reportingAreaCode = "md008",
    stateCode = "MD", parameterName = "PM2.5", aqi = 44L,
    categoryNumber = 1L, categoryName = "Good", actionDay = FALSE,
    discussion = "x"
  )
  result <- finish_forecast(raw, clean_names = TRUE)
  expect_true(is.na(result$forecast_agency))
  expect_named(result, forecast_clean_names)
})

test_that("get_airnow_forecasts() returns the contract for each location type", { # nolint
  httptest2::with_mock_dir("forecasts", {
    by_zip <- get_airnow_forecasts(zip = "90210")
    by_latlong <- get_airnow_forecasts(latitude = 38.3191, longitude = -122.2998) # nolint
    by_area <- get_airnow_forecasts(area = "ca132")
    raw <- get_airnow_forecasts(zip = "90210", clean_names = FALSE)
  })
  for (result in list(by_zip, by_latlong, by_area)) {
    expect_s3_class(result, "tbl_df")
    expect_named(result, forecast_clean_names)
    expect_true(nrow(result) > 0)
    expect_false(anyNA(result$latitude))
  }
  expect_equal(unique(as.character(by_zip$reporting_area_code)), "ca132")
  expect_equal(unique(as.character(by_latlong$reporting_area_code)), "ca064")
  expect_named(raw, forecast_raw_names)
})

test_that("get_airnow_forecasts() returns zero rows when no area serves the point", { # nolint
  httptest2::with_mock_dir("forecasts_nodata", {
    result <- get_airnow_forecasts(latitude = 39.5, longitude = -116.9)
  })
  expect_equal(nrow(result), 0)
  expect_named(result, forecast_clean_names)
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "forecasts|argument_checks|utils")'`
Expected: failures for the new functions only; the pre-existing tests in those files still pass.

- [ ] **Step 3: Append the argument checks**

Append to `R/argument_checks.R`:

```r
check_clean_names <- function(x) {
  if (!is_logical(x, n = 1) || is.na(x)) {
    cli::cli_abort("{.arg clean_names} must be either `TRUE` or `FALSE`")
  }
  x
}

check_area_code <- function(x, arg_name = "area") {
  if (!is_string(x) || is.na(x)) {
    cli::cli_abort("{.arg {arg_name}} must be a single reporting area code such as {.val ca064}") # nolint
  }
  x <- tolower(x)
  if (!grepl("^[a-z]{2}[0-9]{3}$", x)) {
    cli::cli_abort("{.arg {arg_name}} must be a reporting area code such as {.val ca064}; see {.code airnow_areas} or {.fn get_airnow_reporting_area}") # nolint
  }
  x
}

check_area_or_location <- function(zip = NULL,
                                   latitude = NULL,
                                   longitude = NULL,
                                   area = NULL) {
  if (!is.null(area)) {
    if (!is.null(zip) || !is.null(latitude) || !is.null(longitude)) {
      cli::cli_warn("Ignoring {.arg zip}, {.arg latitude}, and {.arg longitude} because {.arg area} was provided") # nolint
    }
    return(list(
      type = "area", zip = NULL, latitude = NULL, longitude = NULL,
      area = check_area_code(area)
    ))
  }
  location <- check_location(zip, latitude, longitude)
  location$area <- NULL
  location
}
```

- [ ] **Step 4: Append the column helper to `R/utils.R`**

```r
#' Add absent columns as typed NA and put the contracted columns first
#'
#' @param x A tibble (possibly 0x0)
#' @param defaults Named list; each value is a length-1 NA of the right type
#' @return A tibble with every name in `defaults`, in that order, followed by
#'   any extra columns `x` already had
#' @noRd
add_missing_columns <- function(x, defaults) {
  n <- nrow(x)
  for (col in names(defaults)) {
    if (!(col %in% names(x))) {
      x[[col]] <- rep(defaults[[col]], n)
    }
  }
  x[c(names(defaults), setdiff(names(x), names(defaults)))]
}
```

- [ ] **Step 5: Implement `R/get_airnow_forecasts.R`**

```r
# Contract for forecast tibbles (raw API names). Typed NA per column.
forecast_columns <- list(
  dateIssue = as.Date(NA),
  dateValid = as.Date(NA),
  reportingArea = NA_character_,
  reportingAreaCode = NA_character_,
  stateCode = NA_character_,
  latitude = NA_real_,
  longitude = NA_real_,
  parameterName = NA_character_,
  aqi = NA_integer_,
  categoryNumber = NA_integer_,
  categoryName = NA_character_,
  actionDay = NA,
  discussion = NA_character_,
  forecastAgency = NA_character_
)


#' Normalize a forecast payload from either forecast service
#' @param x Tibble from [perform_airnow()], possibly 0x0
#' @param clean_names Whether to convert names to snake_case
#' @return A tibble following `forecast_columns`
#' @noRd
finish_forecast <- function(x, clean_names) {
  if (nrow(x) > 0) {
    x$dateIssue <- as.Date(trimws(x$dateIssue))
    x$dateValid <- as.Date(trimws(x$dateValid))
    x$parameterName <- to_parameter_factor(x$parameterName)
    x$categoryName <- to_category_factor(x$categoryName)
    x$categoryNumber <- as.integer(x$categoryNumber)
    x$aqi <- as.integer(x$aqi)
    x$actionDay <- as.logical(x$actionDay)
    x <- join_areas_by_code(x)
  }
  x <- add_missing_columns(x, forecast_columns)
  if (nrow(x) == 0) {
    x$parameterName <- to_parameter_factor(character(0))
    x$categoryName <- to_category_factor(character(0))
  }
  if (clean_names) {
    x <- clean_names(x)
  }
  x
}


#' Get current air quality forecasts
#'
#' `get_airnow_forecasts()` retrieves the forecasts currently issued for a
#' reporting area, located by ZIP code, latitude/longitude, or reporting
#' area code. One row is returned per pollutant per forecast day.
#'
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param area Reporting area code such as `"ca064"`. See [airnow_areas] or
#'   [get_airnow_reporting_area()]. When given, `zip`, `latitude`, and
#'   `longitude` are ignored.
#' @param clean_names Whether column names should be converted to snake_case
#'   (default: `TRUE`). With `FALSE`, the API's lowerCamelCase names are kept.
#' @param api_key AirNow API key
#'
#' @return A tibble with one row per pollutant per forecast day. `parameter`
#'   is a factor with levels `ozone`, `pm2.5`, `pm10`, `co`, `no2`, `so2`;
#'   `category_name` is an ordered factor from Good to Hazardous. `latitude`
#'   and `longitude` describe the reporting area and come from [airnow_areas].
#'   An `aqi` of `-1` means the agency issued a categorical forecast only.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_forecasts(zip = "90210")
#' get_airnow_forecasts(area = "ca064")
#' }
get_airnow_forecasts <- function(zip = NULL,
                                 latitude = NULL,
                                 longitude = NULL,
                                 area = NULL,
                                 clean_names = TRUE,
                                 api_key = get_airnow_key()) {
  query <- check_area_or_location(zip, latitude, longitude, area)
  check_clean_names(clean_names)

  result <- req_airnow() |>
    httr2::req_url_path_append("forecast", "current") |>
    httr2::req_url_query(
      zipCode = query$zip,
      latitude = query$latitude,
      longitude = query$longitude,
      reportingAreaCode = query$area,
      format = "application/json",
      api_key = api_key
    ) |>
    perform_airnow()

  finish_forecast(result, clean_names)
}
```

- [ ] **Step 6: Document, record, verify**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "forecasts|argument_checks|utils")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "forecasts|argument_checks|utils")'
find tests/testthat/forecasts tests/testthat/forecasts_nodata -type f
```
Expected: `FAIL 0` twice, `no key in tests/`, four files under `forecasts/` and one under `forecasts_nodata/`.

- [ ] **Step 7: Commit**

```bash
git add R/argument_checks.R R/utils.R R/get_airnow_forecasts.R NAMESPACE man/ \
  tests/testthat/test-argument_checks.R tests/testthat/test-utils.R \
  tests/testthat/test-get_airnow_forecasts.R tests/testthat/forecasts \
  tests/testthat/forecasts_nodata
git commit -m "$(cat <<'EOF'
feat: add get_airnow_forecasts() on the 2026 forecast/current service

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 5: `get_airnow_forecast_history()`

Implements spec section 4.1 for the historical forecast service. Needed in phase 1 because Task 8's `date` shim uses it.

**Files:**
- Modify: `R/argument_checks.R` (append `check_date_arg()`)
- Create: `R/get_airnow_forecast_history.R`
- Create: `tests/testthat/test-get_airnow_forecast_history.R`
- Modify: `tests/testthat/test-argument_checks.R` (append)
- Create: `tests/testthat/forecast_history/` (recorded)

**Interfaces:**
- Produces: `check_date_arg(x, arg_name)` accepts a single `Date` or a `"YYYY-MM-DD"` string and returns the string form; aborts otherwise.
- Produces: exported `get_airnow_forecast_history(area, start_date, end_date, range = NULL, parameter = NULL, clean_names = TRUE, api_key)`. Same column contract as `get_airnow_forecasts()`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-argument_checks.R`:

```r
test_that("check_date_arg() accepts Dates and ISO strings", {
  expect_equal(check_date_arg(as.Date("2026-01-13"), "d"), "2026-01-13")
  expect_equal(check_date_arg("2026-01-13", "d"), "2026-01-13")
  expect_error(check_date_arg("2026-13-45", "d"))
  expect_error(check_date_arg("Jan 13 2026", "d"))
  expect_error(check_date_arg(NULL, "d"))
  expect_error(check_date_arg(as.Date(NA), "d"))
  expect_error(check_date_arg(as.Date(c("2026-01-13", "2026-01-14")), "d"))
})
```

Create `tests/testthat/test-get_airnow_forecast_history.R`:

```r
test_that("get_airnow_forecast_history() validates inputs", {
  expect_error(get_airnow_forecast_history("Napa", "2026-01-13", "2026-01-14")) # nolint
  expect_error(get_airnow_forecast_history("md008", "2026-01-14", "2026-01-13")) # nolint
  expect_error(get_airnow_forecast_history("md008", "bad", "2026-01-14"))
  expect_error(get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", range = 0)) # nolint
  expect_error(get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", range = 1.5)) # nolint
  expect_error(get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", parameter = "radon")) # nolint
  expect_error(get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14", clean_names = NA)) # nolint
})

test_that("get_airnow_forecast_history() returns the forecast contract", {
  httptest2::with_mock_dir("forecast_history", {
    all_rows <- get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14") # nolint
    narrowed <- get_airnow_forecast_history(
      "md008", as.Date("2026-01-13"), as.Date("2026-01-13"),
      range = 1, parameter = "pm2.5"
    )
  })
  expect_s3_class(all_rows, "tbl_df")
  expect_named(all_rows, c(
    "date_issue", "date_valid", "reporting_area", "reporting_area_code",
    "state_code", "latitude", "longitude", "parameter", "aqi",
    "category_number", "category_name", "action_day", "discussion",
    "forecast_agency"
  ))
  expect_true(nrow(all_rows) > nrow(narrowed))
  expect_true(all(all_rows$date_valid >= as.Date("2026-01-13")))
  expect_true(all(all_rows$date_valid <= as.Date("2026-01-14")))

  expect_equal(nrow(narrowed), 1)
  expect_equal(as.character(narrowed$parameter), "pm2.5")
  expect_equal(narrowed$date_valid, as.Date("2026-01-13"))
  expect_equal(narrowed$date_issue, as.Date("2026-01-12"))
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "forecast_history|argument_checks")'`
Expected: `could not find function` failures.

- [ ] **Step 3: Append `check_date_arg()` to `R/argument_checks.R`**

```r
check_date_arg <- function(x, arg_name) {
  if (inherits(x, "Date") && length(x) == 1 && !is.na(x)) {
    return(format(x, "%Y-%m-%d"))
  }
  if (is_string(x) && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x) &&
    !is.na(as.Date(x, format = "%Y-%m-%d", optional = TRUE))) {
    return(x)
  }
  cli::cli_abort("{.arg {arg_name}} must be a single Date or a string in YYYY-MM-DD format") # nolint
}
```

- [ ] **Step 4: Implement `R/get_airnow_forecast_history.R`**

```r
#' Get past air quality forecasts
#'
#' `get_airnow_forecast_history()` retrieves forecasts that were *valid* on
#' dates in the given range for one reporting area. Every forecast lead time
#' is returned unless `range` narrows it: `range = 1` keeps only the
#' forecast issued the day before each valid date.
#'
#' @inheritParams get_airnow_forecasts
#' @param area Reporting area code such as `"ca064"` (required). See
#'   [airnow_areas] or [get_airnow_reporting_area()].
#' @param start_date,end_date First and last *valid* date to include, as
#'   `Date` objects or `"YYYY-MM-DD"` strings.
#' @param range Optional forecast lead time in days to keep (a positive
#'   whole number). `NULL` (default) keeps every lead time.
#' @param parameter Optional pollutant to keep: one of `"ozone"`,
#'   `"pm2.5"`, `"pm10"`, `"co"`, `"no2"`, `"so2"`.
#'
#' @return A tibble with the same columns as [get_airnow_forecasts()].
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_forecast_history("md008", "2026-01-13", "2026-01-14")
#' get_airnow_forecast_history("md008", "2026-01-13", "2026-01-13",
#'   range = 1, parameter = "pm2.5"
#' )
#' }
get_airnow_forecast_history <- function(area,
                                        start_date,
                                        end_date,
                                        range = NULL,
                                        parameter = NULL,
                                        clean_names = TRUE,
                                        api_key = get_airnow_key()) {
  area <- check_area_code(area)
  start_date <- check_date_arg(start_date, "start_date")
  end_date <- check_date_arg(end_date, "end_date")
  if (as.Date(start_date) > as.Date(end_date)) {
    cli::cli_abort("{.arg start_date} must not be after {.arg end_date}")
  }
  if (!is.null(range) &&
    (!is_integerish(range, n = 1) || is.na(range) || range < 1)) {
    cli::cli_abort("{.arg range} must be a single positive whole number")
  }
  if (!is.null(parameter)) {
    parameter <- toupper(arg_match(parameter, values = parameter_levels))
  }
  check_clean_names(clean_names)

  result <- req_airnow() |>
    httr2::req_url_path_append("forecast", "historical") |>
    httr2::req_url_query(
      reportingAreaCode = area,
      startDate = start_date,
      endDate = end_date,
      forecastRange = range,
      parameter = parameter,
      format = "application/json",
      api_key = api_key
    ) |>
    perform_airnow()

  finish_forecast(result, clean_names)
}
```

- [ ] **Step 5: Document, record, verify**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "forecast_history|argument_checks")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "forecast_history|argument_checks")'
```
Expected: `FAIL 0` twice, `no key in tests/`, two files under `tests/testthat/forecast_history/`.

- [ ] **Step 6: Commit**

```bash
git add R/argument_checks.R R/get_airnow_forecast_history.R NAMESPACE man/ \
  tests/testthat/test-argument_checks.R \
  tests/testthat/test-get_airnow_forecast_history.R tests/testthat/forecast_history
git commit -m "$(cat <<'EOF'
feat: add get_airnow_forecast_history()

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 6: `get_airnow_observations()`

Implements spec sections 4.1, 4.2 (union of columns, `source` factor), and 4.3 (hour convention, `utc_datetime`) for both current-observation services.

**Files:**
- Create: `R/get_airnow_observations.R`
- Create: `tests/testthat/test-get_airnow_observations.R`
- Create: `tests/testthat/observations/` (recorded)

**Interfaces:**
- Produces: `observation_columns` (typed-NA defaults) and `finish_observations(x, source, zip, latitude, longitude, api_key)`.
- Produces: exported `get_airnow_observations(zip, latitude, longitude, area, clean_names = TRUE, api_key)`. Column contract with `clean_names = TRUE`, in order: `date_observed`, `hour_observed`, `local_time_zone`, `utc_datetime`, `reporting_area`, `reporting_area_code`, `reporting_area_agency`, `state_code`, `latitude`, `longitude`, `site_id`, `site_name`, `reporting_agency`, `parameter`, `aqi`, `category_number`, `category_name`, `lookup_behavior`, `considered_monitors`, `lookup_boundary`, `source`. With `clean_names = FALSE`: `dateObserved`, `hourObserved`, `localTimeZone`, `utcDatetime`, `reportingAreaName`, `reportingAreaCode`, `reportingAreaAgency`, `stateCode`, `latitude`, `longitude`, `siteID`, `siteName`, `reportingAgency`, `parameterName`, `nowcastAQI`, `categoryNumber`, `aqiCategoryName`, `lookupBehavior`, `consideredMonitors`, `lookupBoundary`, `source`.
- `hour_observed` keeps the API's end-of-period label (18 means 17:00-17:59). Task 8's shim subtracts one.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-get_airnow_observations.R`:

```r
obs_clean_names <- c(
  "date_observed", "hour_observed", "local_time_zone", "utc_datetime",
  "reporting_area", "reporting_area_code", "reporting_area_agency",
  "state_code", "latitude", "longitude", "site_id", "site_name",
  "reporting_agency", "parameter", "aqi", "category_number",
  "category_name", "lookup_behavior", "considered_monitors",
  "lookup_boundary", "source"
)
obs_raw_names <- c(
  "dateObserved", "hourObserved", "localTimeZone", "utcDatetime",
  "reportingAreaName", "reportingAreaCode", "reportingAreaAgency",
  "stateCode", "latitude", "longitude", "siteID", "siteName",
  "reportingAgency", "parameterName", "nowcastAQI", "categoryNumber",
  "aqiCategoryName", "lookupBehavior", "consideredMonitors",
  "lookupBoundary", "source"
)

ziplatlong_payload <- function() {
  tibble::tibble(
    dateObserved = "2026-09-09", hourObserved = "18:00",
    localTimeZone = "PDT", reportingAreaName = "NW Coastal LA",
    siteID = c("840060374010", "060370113"),
    siteName = c("North Holywood", "West Los Angeles"),
    parameterName = c("PM2.5", "OZONE"), nowcastAQI = c(74L, 34L),
    aqiCategoryName = c("Moderate", "Good"),
    reportingAgency = "South Coast AQMD",
    lookupBehavior = "Closest Reading By Pollutant",
    consideredMonitors = "All", lookupBoundary = "50 Miles"
  )
}

racode_payload <- function() {
  tibble::tibble(
    dateObserved = "2026-09-09", hourObserved = "17:00",
    localTimeZone = "PDT", reportingAreaName = "Napa",
    reportingAreaAgency = "Bay Area Air District",
    reportingAreaCode = "ca064", aqiCategoryName = c("Good", "Good"),
    parameterName = c("OZONE", "PM2.5"), nowcastAQI = c(45L, 20L)
  )
}

test_that("get_airnow_observations() validates inputs", {
  expect_error(get_airnow_observations())
  expect_error(get_airnow_observations(zip = "1234"))
  expect_error(get_airnow_observations(latitude = 91, longitude = 0))
  expect_error(get_airnow_observations(area = "Napa"))
  expect_error(get_airnow_observations(zip = "90210", clean_names = NA))
})

test_that("finish_observations() normalizes a ziplatLong payload", {
  result <- finish_observations(
    ziplatlong_payload(), source = "ziplatlong", zip = "90210"
  )
  expect_named(result, obs_raw_names)
  expect_s3_class(result$dateObserved, "Date")
  expect_equal(result$hourObserved, c(18L, 18L))
  expect_equal(
    result$utcDatetime,
    rep(as.POSIXct("2026-09-10 01:00:00", tz = "UTC"), 2)
  )
  expect_equal(result$reportingAreaCode, c("ca132", "ca132"))
  expect_equal(result$stateCode, c("CA", "CA"))
  expect_false(anyNA(result$latitude))
  expect_equal(result$reportingAreaAgency, rep("South Coast AQMD", 2))
  expect_equal(as.character(result$parameterName), c("pm2.5", "ozone"))
  expect_equal(result$nowcastAQI, c(74L, 34L))
  expect_equal(result$categoryNumber, c(2L, 1L))
  expect_true(is.ordered(result$aqiCategoryName))
  expect_equal(as.character(result$source), c("ziplatlong", "ziplatlong"))
  expect_equal(levels(result$source), c("ziplatlong", "racode"))
})

test_that("finish_observations() normalizes a racode payload with NA site columns", { # nolint
  result <- finish_observations(racode_payload(), source = "racode")
  expect_named(result, obs_raw_names)
  expect_true(all(is.na(result$siteID)))
  expect_true(all(is.na(result$siteName)))
  expect_true(all(is.na(result$lookupBehavior)))
  expect_equal(result$stateCode, c("CA", "CA"))
  expect_false(anyNA(result$latitude))
  expect_equal(result$hourObserved, c(17L, 17L))
  expect_equal(
    result$utcDatetime,
    rep(as.POSIXct("2026-09-10 00:00:00", tz = "UTC"), 2)
  )
  expect_equal(as.character(result$source), c("racode", "racode"))
})

test_that("finish_observations() keeps the API's midnight label unshifted", {
  x <- ziplatlong_payload()[1, ]
  x$dateObserved <- "2026-09-10"
  x$hourObserved <- "00:00"
  result <- finish_observations(x, source = "ziplatlong", zip = "90210")
  expect_equal(result$hourObserved, 0L)
  expect_equal(result$dateObserved, as.Date("2026-09-10"))
  expect_equal(result$utcDatetime, as.POSIXct("2026-09-10 07:00:00", tz = "UTC")) # nolint
})

test_that("finish_observations() warns on a join miss and keeps the row", {
  x <- ziplatlong_payload()[1, ]
  x$reportingAreaName <- "Atlantis"
  expect_warning(
    result <- finish_observations(x, source = "ziplatlong", zip = "90210"),
    "Atlantis"
  )
  expect_equal(nrow(result), 1)
  expect_true(is.na(result$reportingAreaCode))
  expect_true(is.na(result$latitude))
  expect_true(is.na(result$utcDatetime))
  expect_equal(result$nowcastAQI, 74L)
})

test_that("finish_observations() warns on an unmatched time zone", {
  x <- ziplatlong_payload()[1, ]
  x$localTimeZone <- "XYZ"
  expect_warning(
    result <- finish_observations(x, source = "ziplatlong", zip = "90210"),
    "XYZ"
  )
  expect_true(is.na(result$utcDatetime))
  expect_equal(result$hourObserved, 18L)
})

test_that("finish_observations() returns the full contract for zero rows", {
  result <- finish_observations(tibble::tibble(), source = "racode")
  expect_named(result, obs_raw_names)
  expect_equal(nrow(result), 0)
  expect_s3_class(result$utcDatetime, "POSIXct")
  expect_s3_class(result$source, "factor")
})

test_that("get_airnow_observations() returns the contract for each location type", { # nolint
  local_area_code_cache()
  httptest2::with_mock_dir("observations", {
    by_zip <- get_airnow_observations(zip = "90210")
    by_latlong <- get_airnow_observations(latitude = 38.3191, longitude = -122.2998) # nolint
    by_area <- get_airnow_observations(area = "ca064")
    raw <- get_airnow_observations(zip = "90210", clean_names = FALSE)
  })
  for (result in list(by_zip, by_latlong, by_area)) {
    expect_s3_class(result, "tbl_df")
    expect_named(result, obs_clean_names)
    expect_true(nrow(result) > 0)
    expect_false(anyNA(result$reporting_area_code))
    expect_false(anyNA(result$utc_datetime))
  }
  expect_equal(unique(as.character(by_zip$source)), "ziplatlong")
  expect_equal(unique(as.character(by_area$source)), "racode")
  expect_true(all(is.na(by_area$site_id)))
  expect_false(anyNA(by_zip$site_id))
  expect_named(raw, obs_raw_names)
})

test_that("get_airnow_observations() returns zero rows when nothing is nearby", { # nolint
  httptest2::with_mock_dir("observations_nodata", {
    result <- get_airnow_observations(latitude = 39.5, longitude = -116.9)
  })
  expect_equal(nrow(result), 0)
  expect_named(result, obs_clean_names)
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "get_airnow_observations")'`
Expected: `could not find function` failures.

- [ ] **Step 3: Implement `R/get_airnow_observations.R`**

```r
# Contract for observation tibbles (raw API names), the union of what the
# ziplatLong and racode services return plus derived and joined columns.
observation_columns <- list(
  dateObserved = as.Date(NA),
  hourObserved = NA_integer_,
  localTimeZone = NA_character_,
  utcDatetime = as.POSIXct(NA, tz = "UTC"),
  reportingAreaName = NA_character_,
  reportingAreaCode = NA_character_,
  reportingAreaAgency = NA_character_,
  stateCode = NA_character_,
  latitude = NA_real_,
  longitude = NA_real_,
  siteID = NA_character_,
  siteName = NA_character_,
  reportingAgency = NA_character_,
  parameterName = NA_character_,
  nowcastAQI = NA_integer_,
  categoryNumber = NA_integer_,
  aqiCategoryName = NA_character_,
  lookupBehavior = NA_character_,
  consideredMonitors = NA_character_,
  lookupBoundary = NA_character_,
  source = NA_character_
)


#' Normalize an observation payload from either observation service
#'
#' @param x Tibble from [perform_airnow()], possibly 0x0
#' @param source `"ziplatlong"` or `"racode"`
#' @param zip,latitude,longitude The original query, needed only to resolve
#'   ambiguous area names on the ziplatlong path
#' @param api_key API key, needed only for the ambiguous-zip case
#' @return A tibble following `observation_columns` (raw names)
#' @noRd
finish_observations <- function(x,
                                source,
                                zip = NULL,
                                latitude = NULL,
                                longitude = NULL,
                                api_key = get_airnow_key()) {
  if (nrow(x) > 0) {
    if (source == "ziplatlong") {
      x <- join_areas_by_name(x, zip, latitude, longitude, api_key)
    } else {
      x <- join_areas_by_code(x)
    }
    x$dateObserved <- as.Date(trimws(x$dateObserved))
    x$hourObserved <- hour_label_to_integer(x$hourObserved)
    x$parameterName <- to_parameter_factor(x$parameterName)
    x$aqiCategoryName <- to_category_factor(x$aqiCategoryName)
    x$categoryNumber <- as.integer(x$aqiCategoryName)
    x$nowcastAQI <- as.integer(x$nowcastAQI)
    x$utcDatetime <- derive_utc_datetime(
      x$dateObserved, x$hourObserved, x$localTimeZone, x$reportingAreaCode
    )
    x$source <- rep(source, nrow(x))
  }

  x <- add_missing_columns(x, observation_columns)
  if (nrow(x) == 0) {
    x$parameterName <- to_parameter_factor(character(0))
    x$aqiCategoryName <- to_category_factor(character(0))
  }
  x$source <- factor(x$source, levels = c("ziplatlong", "racode"))
  x
}


#' Get current air quality observations
#'
#' `get_airnow_observations()` retrieves the most recent hourly readings for
#' a location. Locate it by ZIP code or latitude/longitude, or give a
#' reporting area code. The two forms use different AirNow services with
#' different methodologies:
#'
#' * By ZIP code or coordinates, AirNow returns the closest reading for each
#'   pollutant within the reporting area's search radius, and names the site
#'   it came from (`site_id`, `site_name`).
#' * By `area`, AirNow returns the area's official value for each pollutant
#'   and omits the site columns, which are `NA`.
#'
#' The `source` column records which service produced each row.
#'
#' @section Requests made:
#' One request per call, plus one extra request (cached for the session)
#' when a ZIP code's reporting area shares its name with an area in another
#' state. There are 26 such names; see [airnow_areas]. All requests count
#' against AirNow's 500-per-hour limit.
#'
#' @section Time columns:
#' `hour_observed` uses AirNow's convention of labelling an hour by its
#' **end**: `18` means the period 17:00-17:59. `date_observed` and
#' `hour_observed` are local to each reporting area, and `local_time_zone`
#' is an abbreviation R cannot interpret. `utc_datetime` is derived from the
#' reporting area's metadata in [airnow_areas] and is the column to use when
#' comparing areas or joining with [get_airnow_monitors()]. It is `NA` when
#' the area or its time zone cannot be matched.
#'
#' @inheritParams get_airnow_forecasts
#'
#' @return A tibble with one row per pollutant. `parameter` is a factor with
#'   levels `ozone`, `pm2.5`, `pm10`, `co`, `no2`, `so2`; `category_name` is
#'   an ordered factor; `aqi` is the NowCast AQI.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_observations(zip = "90210")
#' get_airnow_observations(latitude = 38.3191, longitude = -122.2998)
#' get_airnow_observations(area = "ca064")
#' }
get_airnow_observations <- function(zip = NULL,
                                    latitude = NULL,
                                    longitude = NULL,
                                    area = NULL,
                                    clean_names = TRUE,
                                    api_key = get_airnow_key()) {
  query <- check_area_or_location(zip, latitude, longitude, area)
  check_clean_names(clean_names)

  if (query$type == "area") {
    source <- "racode"
    req <- req_airnow() |>
      httr2::req_url_path_append("observation", "current", "racode") |>
      httr2::req_url_query(
        reportingAreaCode = query$area,
        format = "application/json",
        api_key = api_key
      )
  } else {
    source <- "ziplatlong"
    req <- req_airnow() |>
      httr2::req_url_path_append("observation", "current", "ziplatLong") |>
      httr2::req_url_query(
        zipCode = query$zip,
        latitude = query$latitude,
        longitude = query$longitude,
        format = "application/json",
        api_key = api_key
      )
  }

  result <- perform_airnow(req)
  result <- finish_observations(
    result, source,
    zip = query$zip, latitude = query$latitude, longitude = query$longitude,
    api_key = api_key
  )

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}
```

- [ ] **Step 4: Document, record, verify**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "get_airnow_observations")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "get_airnow_observations")'
```
Expected: `FAIL 0` twice, `no key in tests/`, three files under `tests/testthat/observations/` and one under `observations_nodata/`. (The 90210 raw and clean calls share one fixture.)

- [ ] **Step 5: Commit**

```bash
git add R/get_airnow_observations.R NAMESPACE man/ \
  tests/testthat/test-get_airnow_observations.R tests/testthat/observations \
  tests/testthat/observations_nodata
git commit -m "$(cat <<'EOF'
feat: add get_airnow_observations() on the 2026 observation services

Fronts both /observation/current/ziplatLong and /racode with a stable
union of columns, a source factor, and a derived utc_datetime.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 7: `get_airnow_monitors()` and the `get_airnow_area()` shim

Implements the rename in spec section 4.1 and one of the five shims in section 5. The service is unaffected by the retirement; only the name and transport change.

**Files:**
- Rename: `R/get_airnow_area.R` to `R/get_airnow_monitors.R` (and edit)
- Modify: `R/deprecated.R` (append)
- Rename: `tests/testthat/test-get_airnow_area.R` to `tests/testthat/test-get_airnow_monitors.R` (and edit)
- Create: `tests/testthat/test-deprecated.R`
- Create: `tests/testthat/monitors/` (recorded)

**Interfaces:**
- Produces: exported `get_airnow_monitors()` with exactly the signature and columns `get_airnow_area()` has today.
- Produces: `get_airnow_area()` as a deprecated wrapper.

- [ ] **Step 1: Rename the files**

Run:
```bash
git mv R/get_airnow_area.R R/get_airnow_monitors.R
git mv tests/testthat/test-get_airnow_area.R tests/testthat/test-get_airnow_monitors.R
sed -i '' 's/get_airnow_area/get_airnow_monitors/g' R/get_airnow_monitors.R tests/testthat/test-get_airnow_monitors.R
grep -c "get_airnow_area" R/get_airnow_monitors.R tests/testthat/test-get_airnow_monitors.R
```
Expected: both counts are `0`.

- [ ] **Step 2: Update the implementation to the new transport**

In `R/get_airnow_monitors.R`, replace the block from `httr2::req_perform()` through `tibble::as_tibble()` (the lines reading

```r
    httr2::req_perform()

  result <- result_raw |>
    httr2::resp_body_string() |>
    jsonlite::fromJSON(flatten = TRUE) |>
    tibble::as_tibble()
```
) with

```r
    perform_airnow()

  result <- result_raw
```

Also fix the roxygen title/description at the top of the file so it reads:

```r
#' Get air quality data from monitoring sites in a region
#'
#' `get_airnow_monitors()` retrieves readings from every monitoring site
#' inside a bounding box. Before airnow 0.2.0 this function was called
#' `get_airnow_area()`.
```

- [ ] **Step 3: Convert the network test to a fixture**

In `tests/testthat/test-get_airnow_monitors.R`, in the test `"get_airnow_monitors() produces the expected outputs"`, delete the `skip_if(...)` call (three lines) and wrap the four `get_airnow_monitors(...)` calls in one mock block. The test body becomes:

```r
  httptest2::with_mock_dir("monitors", {
    result <- get_airnow_monitors(
      box = c(-125.394211, 45.295897, -116.736984, 49.172497)
    )
    result_allargs_clean <- get_airnow_monitors(
      box = c(-125.394211, 45.295897, -116.736984, 49.172497),
      data_type = "both",
      verbose = TRUE,
      raw_concentrations = TRUE
    )
    result_noclean <- get_airnow_monitors(
      box = c(-125.394211, 45.295897, -116.736984, 49.172497),
      clean_names = FALSE
    )
    result_allargs_noclean <- get_airnow_monitors(
      box = c(-125.394211, 45.295897, -116.736984, 49.172497),
      data_type = "both",
      verbose = TRUE,
      raw_concentrations = TRUE,
      clean_names = FALSE
    )
  })
```

followed by the existing `expect_*` assertions, unchanged, in their existing order (the `colnames_raw` and `colnames_clean` vectors stay above the block).

- [ ] **Step 4: Add the shim and its test**

Append to `R/deprecated.R`:

```r
#' @rdname airnow-deprecated
#' @inheritParams get_airnow_monitors
#' @export
get_airnow_area <- function(box,
                            parameters = "pm25",
                            start_time = NULL,
                            end_time = NULL,
                            monitor_type = "both",
                            data_type = c("aqi", "concentrations", "both"),
                            verbose = FALSE,
                            raw_concentrations = FALSE,
                            clean_names = TRUE,
                            api_key = get_airnow_key()) {
  lifecycle::deprecate_warn("0.2.0", "get_airnow_area()", "get_airnow_monitors()") # nolint
  get_airnow_monitors(
    box = box,
    parameters = parameters,
    start_time = start_time,
    end_time = end_time,
    monitor_type = monitor_type,
    data_type = data_type,
    verbose = verbose,
    raw_concentrations = raw_concentrations,
    clean_names = clean_names,
    api_key = api_key
  )
}
```

Also add the row `#' | `get_airnow_area()` | [get_airnow_monitors()] |` to the table in the `airnow-deprecated` roxygen block at the top of that file.

Create `tests/testthat/test-deprecated.R`:

```r
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
```

- [ ] **Step 5: Document, record, verify**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "monitors|deprecated")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "monitors|deprecated")'
grep -n "get_airnow_monitors\|get_airnow_area" NAMESPACE
```
Expected: `FAIL 0` twice, `no key in tests/`, four files under `tests/testthat/monitors/`, and both functions exported.

- [ ] **Step 6: Commit**

```bash
git add -A R/ NAMESPACE man/ tests/testthat/
git commit -m "$(cat <<'EOF'
feat: rename get_airnow_area() to get_airnow_monitors(); deprecate the old name

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 8: `get_airnow_conditions()` and `get_airnow_forecast()` compatibility shims

Implements spec sections 5.1, 5.2, 5.3. The goal is that the assertion blocks in the two existing test files pass with their column lists untouched.

**Files:**
- Delete: `R/get_airnow_conditions.R`, `R/get_airnow_forecast.R`
- Create: `R/legacy.R` (pure transforms)
- Modify: `R/deprecated.R` (append the two shims)
- Modify: `tests/testthat/test-get_airnow_conditions.R`, `tests/testthat/test-get_airnow_forecast.R` (wrap network calls only)
- Create: `tests/testthat/test-legacy.R`
- Create: `tests/testthat/legacy_conditions/`, `tests/testthat/legacy_forecast/` (recorded)

**Interfaces:**
- Produces: `observations_to_legacy(x)` takes a clean-named `get_airnow_observations()` tibble and returns the 11 legacy columns: `DateObserved`, `HourObserved`, `LocalTimeZone`, `ReportingArea`, `StateCode`, `Latitude`, `Longitude`, `ParameterName`, `AQI`, `Category.Number`, `Category.Name`. Hour is shifted to the old start-of-period label; a `0` wraps to `23` on the previous date.
- Produces: `forecasts_to_legacy(x)` takes a clean-named forecast tibble and returns the 12 legacy columns: `DateIssue`, `DateForecast`, `ReportingArea`, `StateCode`, `Latitude`, `Longitude`, `ParameterName`, `AQI`, `ActionDay`, `Discussion`, `Category.Number`, `Category.Name`.
- Produces: deprecated exported `get_airnow_conditions()` and `get_airnow_forecast()` with their existing signatures.

- [ ] **Step 1: Write the failing tests for the transforms**

Create `tests/testthat/test-legacy.R`:

```r
legacy_observation_input <- function() {
  tibble::tibble(
    date_observed = as.Date("2026-09-09"), hour_observed = 18L,
    local_time_zone = "PDT",
    utc_datetime = as.POSIXct("2026-09-10 01:00:00", tz = "UTC"),
    reporting_area = "NW Coastal LA", reporting_area_code = "ca132",
    reporting_area_agency = "South Coast AQMD", state_code = "CA",
    latitude = 34.0505, longitude = -118.4566, site_id = "840060374010",
    site_name = "North Holywood", reporting_agency = "South Coast AQMD",
    parameter = factor(c("ozone", "pm2.5"), levels = parameter_levels),
    aqi = c(34L, 74L), category_number = c(1L, 2L),
    category_name = factor(c("Good", "Moderate"), levels = category_levels, ordered = TRUE), # nolint
    lookup_behavior = "Closest Reading By Pollutant",
    considered_monitors = "All", lookup_boundary = "50 Miles",
    source = factor("ziplatlong", levels = c("ziplatlong", "racode"))
  )
}

test_that("observations_to_legacy() reproduces the old columns and vocabulary", { # nolint
  result <- observations_to_legacy(legacy_observation_input())
  expect_named(result, c(
    "DateObserved", "HourObserved", "LocalTimeZone", "ReportingArea",
    "StateCode", "Latitude", "Longitude", "ParameterName", "AQI",
    "Category.Number", "Category.Name"
  ))
  expect_equal(result$HourObserved, c(17L, 17L))
  expect_equal(result$DateObserved, as.Date(c("2026-09-09", "2026-09-09")))
  expect_equal(as.character(result$ParameterName), c("O3", "PM2.5"))
  expect_s3_class(result$ParameterName, "factor")
  expect_s3_class(result$LocalTimeZone, "factor")
  expect_s3_class(result$ReportingArea, "factor")
  expect_s3_class(result$StateCode, "factor")
  expect_false(is.ordered(result$Category.Name))
  expect_equal(levels(result$Category.Name), category_levels)
  expect_equal(result$AQI, c(34L, 74L))
  expect_equal(result$Category.Number, c(1L, 2L))
})

test_that("observations_to_legacy() wraps midnight to 23:00 the previous day", { # nolint
  # ASSUMPTION pending the midnight probe (spec section 5.1): a "00:00"
  # label describes 23:00-23:59 of the previous calendar day.
  x <- legacy_observation_input()[1, ]
  x$hour_observed <- 0L
  x$date_observed <- as.Date("2026-09-10")
  result <- observations_to_legacy(x)
  expect_equal(result$HourObserved, 23L)
  expect_equal(result$DateObserved, as.Date("2026-09-09"))
})

test_that("observations_to_legacy() is NA-safe on the hour", {
  x <- legacy_observation_input()[1, ]
  x$hour_observed <- NA_integer_
  result <- observations_to_legacy(x)
  expect_true(is.na(result$HourObserved))
  expect_equal(result$DateObserved, as.Date("2026-09-09"))
})

test_that("observations_to_legacy() handles zero rows", {
  x <- legacy_observation_input()[0, ]
  result <- observations_to_legacy(x)
  expect_equal(nrow(result), 0)
  expect_equal(ncol(result), 11)
})

test_that("forecasts_to_legacy() reproduces the old columns", {
  x <- tibble::tibble(
    date_issue = as.Date("2026-09-08"), date_valid = as.Date("2026-09-09"),
    reporting_area = "NW Coastal LA", reporting_area_code = "ca132",
    state_code = "CA", latitude = 34.0505, longitude = -118.4566,
    parameter = factor(c("ozone", "pm2.5"), levels = parameter_levels),
    aqi = c(34L, 53L), category_number = c(1L, 2L),
    category_name = factor(c("Good", "Moderate"), levels = category_levels, ordered = TRUE), # nolint
    action_day = FALSE, discussion = "", forecast_agency = "South Coast AQMD"
  )
  result <- forecasts_to_legacy(x)
  expect_named(result, c(
    "DateIssue", "DateForecast", "ReportingArea", "StateCode", "Latitude",
    "Longitude", "ParameterName", "AQI", "ActionDay", "Discussion",
    "Category.Number", "Category.Name"
  ))
  expect_equal(result$DateForecast, as.Date(c("2026-09-09", "2026-09-09")))
  expect_equal(as.character(result$ParameterName), c("O3", "PM2.5"))
  expect_false(is.ordered(result$Category.Name))
  expect_equal(result$ActionDay, c(FALSE, FALSE))
  expect_equal(nrow(forecasts_to_legacy(x[0, ])), 0)
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "legacy")'`
Expected: `could not find function "observations_to_legacy"`.

- [ ] **Step 3: Implement `R/legacy.R`**

```r
# Pure transforms from the 0.2.0 tibbles back to the pre-2026 column
# contracts. Used only by the deprecated shims in R/deprecated.R.

# Canonical parameter level -> the old services' spelling
legacy_parameter_names <- c(
  ozone = "O3", pm2.5 = "PM2.5", pm10 = "PM10",
  co = "CO", no2 = "NO2", so2 = "SO2"
)


#' Convert get_airnow_observations() output to the get_airnow_conditions()
#' contract
#'
#' The old service labelled an hour by its start, the new one by its end
#' (spec section 2.3), so the hour is decremented. A `0` becomes `23` on the
#' previous date. ASSUMPTION pending the scheduled midnight probe (spec
#' section 5.1): this is the only self-consistent reading of "labelled by
#' period end", but no "00:00" response has been observed yet.
#'
#' @param x Clean-named tibble from [get_airnow_observations()]
#' @return A tibble with the 11 legacy columns
#' @noRd
observations_to_legacy <- function(x) {
  hour <- x$hour_observed - 1L
  date <- x$date_observed
  wrap <- !is.na(hour) & hour < 0L
  hour[wrap] <- 23L
  date[wrap] <- date[wrap] - 1L

  parameter <- unname(legacy_parameter_names[as.character(x$parameter)])

  tibble::tibble(
    DateObserved = date,
    HourObserved = hour,
    LocalTimeZone = as.factor(x$local_time_zone),
    ReportingArea = as.factor(x$reporting_area),
    StateCode = as.factor(x$state_code),
    Latitude = x$latitude,
    Longitude = x$longitude,
    ParameterName = as.factor(parameter),
    AQI = x$aqi,
    Category.Number = x$category_number,
    Category.Name = factor(as.character(x$category_name), levels = category_levels) # nolint
  )
}


#' Convert a clean-named forecast tibble to the get_airnow_forecast() contract
#' @param x Clean-named tibble from [get_airnow_forecasts()] or
#'   [get_airnow_forecast_history()]
#' @return A tibble with the 12 legacy columns
#' @noRd
forecasts_to_legacy <- function(x) {
  parameter <- unname(legacy_parameter_names[as.character(x$parameter)])

  tibble::tibble(
    DateIssue = x$date_issue,
    DateForecast = x$date_valid,
    ReportingArea = as.factor(x$reporting_area),
    StateCode = as.factor(x$state_code),
    Latitude = x$latitude,
    Longitude = x$longitude,
    ParameterName = as.factor(parameter),
    AQI = x$aqi,
    ActionDay = x$action_day,
    Discussion = x$discussion,
    Category.Number = x$category_number,
    Category.Name = factor(as.character(x$category_name), levels = category_levels) # nolint
  )
}
```

- [ ] **Step 4: Run the transform tests**

Run: `AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "legacy")'`
Expected: `FAIL 0`.

- [ ] **Step 5: Replace the old functions with shims**

Run:
```bash
git rm -q R/get_airnow_conditions.R R/get_airnow_forecast.R
```

Append to `R/deprecated.R`:

```r
#' @rdname airnow-deprecated
#' @param zip ZIP code, a 5-digit numeric string (e.g., `"90210"`)
#' @param latitude Latitude in decimal degrees
#' @param longitude Longitude in decimal degrees
#' @param distance Ignored since airnow 0.2.0. The 2026 AirNow services
#'   search a fixed radius for each reporting area.
#' @param clean_names Whether or not column names should be cleaned
#'   (default: `TRUE`)
#' @param api_key AirNow API key
#' @export
get_airnow_conditions <- function(zip = NULL,
                                  latitude = NULL,
                                  longitude = NULL,
                                  distance = NULL,
                                  clean_names = TRUE,
                                  api_key = get_airnow_key()) {
  location <- check_location(zip, latitude, longitude)
  distance <- check_distance(distance)
  check_clean_names(clean_names)

  lifecycle::deprecate_warn(
    "0.2.0", "get_airnow_conditions()", "get_airnow_observations()",
    details = c(
      "AirNow retired the service behind this function on 2026-09-30.",
      "This shim calls the replacement service and reshapes the result. Row counts and AQI values may differ from before; LocalTimeZone is now correct; HourObserved keeps the old start-of-hour convention." # nolint
    )
  )
  if (!is.null(distance)) {
    cli::cli_warn("{.arg distance} is ignored: the AirNow API now searches a fixed radius for each reporting area") # nolint
  }

  result <- get_airnow_observations(
    zip = location$zip,
    latitude = location$latitude,
    longitude = location$longitude,
    clean_names = TRUE,
    api_key = api_key
  )
  result <- observations_to_legacy(result)

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}


#' @rdname airnow-deprecated
#' @param date Optional date of forecast as a `"YYYY-MM-DD"` string. Since
#'   airnow 0.2.0 this returns forecasts *valid* on that date with a
#'   one-day lead time; the old service also returned forecasts *issued* on
#'   that date.
#' @export
get_airnow_forecast <- function(zip = NULL,
                                latitude = NULL,
                                longitude = NULL,
                                distance = NULL,
                                date = NULL,
                                clean_names = TRUE,
                                api_key = get_airnow_key()) {
  location <- check_location(zip, latitude, longitude)
  distance <- check_distance(distance)
  date <- check_date(date)
  check_clean_names(clean_names)

  lifecycle::deprecate_warn(
    "0.2.0", "get_airnow_forecast()", "get_airnow_forecasts()",
    details = c(
      "AirNow retired the service behind this function on 2026-09-30.",
      "This shim calls the replacement service and reshapes the result. Row counts may differ; `date` now selects forecasts valid on that date only." # nolint
    )
  )
  if (!is.null(distance)) {
    cli::cli_warn("{.arg distance} is ignored: the AirNow API now searches a fixed radius for each reporting area") # nolint
  }

  if (is.null(date)) {
    result <- get_airnow_forecasts(
      zip = location$zip,
      latitude = location$latitude,
      longitude = location$longitude,
      clean_names = TRUE,
      api_key = api_key
    )
  } else {
    area <- resolve_area_code(
      zip = location$zip,
      latitude = location$latitude,
      longitude = location$longitude,
      api_key = api_key
    )
    result <- get_airnow_forecast_history(
      area = area,
      start_date = date,
      end_date = date,
      range = 1,
      clean_names = TRUE,
      api_key = api_key
    )
  }
  result <- forecasts_to_legacy(result)

  if (clean_names) {
    result <- clean_names(result)
  }
  result
}
```

Add these rows to the table in the `airnow-deprecated` roxygen block at the top of `R/deprecated.R`:

```
#' | `get_airnow_conditions()` | [get_airnow_observations()] |
#' | `get_airnow_forecast()` | [get_airnow_forecasts()] |
```

- [ ] **Step 6: Wrap the legacy tests' network calls in fixtures**

In `tests/testthat/test-get_airnow_conditions.R`, in the test `"get_airnow_conditions() produces the expected outputs"`, delete the `skip_if(...)` call and replace the two lines

```r
  result <- get_airnow_conditions(zip = "98101")
```
and
```r
  result_noclean <- get_airnow_conditions(zip = "98101", clean_names = FALSE)
```
with, respectively:

```r
  httptest2::with_mock_dir("legacy_conditions", {
    lifecycle::expect_deprecated(result <- get_airnow_conditions(zip = "98101")) # nolint
  })
```
and
```r
  httptest2::with_mock_dir("legacy_conditions", {
    lifecycle::expect_deprecated(
      result_noclean <- get_airnow_conditions(zip = "98101", clean_names = FALSE) # nolint
    )
  })
```

Leave every `expect_setequal(colnames(...), c(...))` block byte-for-byte unchanged.

Do the same in `tests/testthat/test-get_airnow_forecast.R` with the mock directory `"legacy_forecast"` and the function `get_airnow_forecast`. Then add one more test at the end of that file for the `date` path:

```r
test_that("get_airnow_forecast(date = ) narrows to forecasts valid that day", {
  local_area_code_cache()
  httptest2::with_mock_dir("legacy_forecast_date", {
    lifecycle::expect_deprecated(
      result <- get_airnow_forecast(zip = "98101", date = "2026-01-13")
    )
  })
  expect_true(nrow(result) > 0)
  expect_equal(unique(result$date_forecast), as.Date("2026-01-13"))
  expect_equal(unique(result$date_issued), as.Date("2026-01-12"))
})
```

- [ ] **Step 7: Document, record, verify**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "get_airnow_conditions|get_airnow_forecast$|legacy")'
grep -rlF "$AIRNOW_API_TOKEN" tests/testthat && echo "KEY LEAKED" || echo "no key in tests/"
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test()'
ls R/
```
Expected: `FAIL 0` on the filtered run and on the full suite, `no key in tests/`, and `R/` no longer contains `get_airnow_conditions.R` or `get_airnow_forecast.R`. The `testthat` filter `get_airnow_forecast$` matches only the legacy file, not `get_airnow_forecasts`.

Fixture note: the zip 98101 requests made through the shims hit `observation/current/ziplatLong` and `forecast/current`, and the `date` path hits `forecast/current` (area resolution) and `forecast/historical`. Expect one JSON file per distinct request under each mock directory.

- [ ] **Step 8: Commit**

```bash
git add -A R/ NAMESPACE man/ tests/testthat/
git commit -m "$(cat <<'EOF'
feat: deprecate get_airnow_conditions() and get_airnow_forecast() as shims

Both now call the 2026 services and reshape to the old column contracts.
HourObserved keeps the old start-of-hour label; distance is ignored with
a warning; date selects forecasts valid that day.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 9: Live smoke test

Implements spec section 7, layer 3. Recorded fixtures cannot detect the API drifting; this file re-checks the facts most likely to change. It never runs on CRAN and skips unless a real key is present, so on CI (which sets the secret) it runs on every push. The weekly schedule is phase 2.

**Files:**
- Create: `tests/testthat/test-live.R`

- [ ] **Step 1: Write the test file**

Create `tests/testthat/test-live.R`:

```r
# Live checks against the real API. Skipped on CRAN and whenever the key is
# absent or the placeholder from setup.R. Each check is a fact from the
# spec's section 2 that a recorded fixture cannot see drifting.
skip_if_no_live_key <- function() {
  testthat::skip_on_cran()
  key <- Sys.getenv("AIRNOW_API_KEY")
  testthat::skip_if(
    !nzchar(key) || identical(key, "test-key"),
    "No real AIRNOW_API_KEY set; live smoke test skipped"
  )
}

live_request <- function(path, ...) {
  req_airnow() |>
    httr2::req_url_path_append(path) |>
    httr2::req_url_query(
      ...,
      format = "application/json",
      api_key = get_airnow_key(ask = FALSE)
    ) |>
    httr2::req_perform()
}

test_that("live: api_key is accepted and the response is served over HTTPS", { # nolint
  skip_if_no_live_key()
  resp <- live_request("forecast/current", zipCode = "90210")
  expect_equal(httr2::resp_status(resp), 200)
  expect_match(resp$url, "^https://")
})

test_that("live: distance is still ignored by the new observation service", {
  skip_if_no_live_key()
  a <- live_request("observation/current/ziplatLong", zipCode = "90210")
  b <- live_request("observation/current/ziplatLong", zipCode = "90210", distance = 25) # nolint
  expect_equal(httr2::resp_body_string(a), httr2::resp_body_string(b))
})

test_that("live: forecast/current accepts a reporting area code", {
  skip_if_no_live_key()
  result <- get_airnow_forecasts(area = "ca132")
  expect_true(nrow(result) > 0)
  expect_equal(unique(as.character(result$reporting_area_code)), "ca132")
})

test_that("live: area names still join and time columns are sane", {
  skip_if_no_live_key()
  local_area_code_cache()
  obs <- expect_no_warning(get_airnow_observations(zip = "90210"))
  expect_true(nrow(obs) > 0)
  expect_false(anyNA(obs$reporting_area_code))
  expect_false(anyNA(obs$utc_datetime))
  expect_true(all(obs$hour_observed >= 0L & obs$hour_observed <= 23L))
  # End-of-period labels for the latest completed hour fall inside this
  # window. (The one-hour offset itself can only be verified against the
  # old service, which is gone after 2026-09-30.)
  expect_true(all(obs$utc_datetime <= Sys.time() + 15 * 60))
  expect_true(all(obs$utc_datetime >= Sys.time() - 6 * 3600))
})

test_that("live: pollutant and category vocabularies are still recognised", {
  skip_if_no_live_key()
  fc <- expect_no_warning(get_airnow_forecasts(zip = "90210"))
  expect_false(anyNA(fc$parameter))
  expect_false(anyNA(fc$category_name))
})
```

- [ ] **Step 2: Confirm it skips without a key and runs with one**

Run:
```bash
AIRNOW_API_KEY=test-key Rscript -e 'devtools::test(filter = "live")'
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::test(filter = "live")'
```
Expected: first run `[ FAIL 0 | WARN 0 | SKIP 5 | PASS 0 ]`; second run `FAIL 0`, `SKIP 0`, with roughly 14 passes. This second run makes about seven live requests.

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-live.R
git commit -m "$(cat <<'EOF'
test: add live smoke test for API facts that fixtures cannot see drift

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 10: Documentation, version, and release gate

Implements the remaining bits of spec sections 6 (help-page cost note), 7 (visible skip message no longer needed: nothing skips), and 10 (release).

**Files:**
- Modify: `DESCRIPTION` (Version)
- Modify: `NEWS.md`
- Modify: `_pkgdown.yml`
- Modify: `README.Rmd` and regenerate `README.md`
- Modify: `cran-comments.md`

- [ ] **Step 1: Bump the version**

Run:
```bash
sed -i '' 's/^Version: 0.1.1$/Version: 0.2.0/' DESCRIPTION
grep -n "^Version" DESCRIPTION
```
Expected: `Version: 0.2.0`.

- [ ] **Step 2: Write the NEWS entry**

Prepend to `NEWS.md` (above `# airnow 0.1.1`):

```markdown
# airnow 0.2.0

AirNow retired the web services behind `get_airnow_conditions()` and
`get_airnow_forecast()` on 2026-09-30. This release moves the package to the
replacement services released in June 2026.

## New functions

* `get_airnow_observations()` returns current readings by ZIP code,
  coordinates, or reporting area code, with a derived `utc_datetime` column.
* `get_airnow_forecasts()` returns the forecasts currently issued for a
  location.
* `get_airnow_forecast_history()` returns past forecasts for a reporting
  area and date range.
* `get_airnow_reporting_area()` finds the reporting area that serves a
  location.
* `get_airnow_monitors()` is the new name for `get_airnow_area()`.
* `get_airnow_key()` and `set_airnow_key()` replace the token-named
  credential helpers.

## New dataset

* `airnow_areas` lists every AirNow reporting area with its code, location,
  time zone, and agency.

## Deprecations

* `get_airnow_conditions()`, `get_airnow_forecast()`, `get_airnow_area()`,
  `get_airnow_token()`, and `set_airnow_token()` still work but warn. The
  first two call the new services and reshape the result to their old
  columns. Row counts and AQI values can differ from the retired services
  because AirNow changed its lookup methodology; `LocalTimeZone` is now
  correct where it was wrong before; `distance` is ignored; and
  `get_airnow_forecast(date = )` returns forecasts valid on that date only.

## Fixes

* Requests use HTTPS. Previously the API key made its first hop over plain
  HTTP before a redirect.
* API error messages are reported instead of a malformed data frame.
  Requests that match no data return a zero-row tibble.
* `aqi_color()` and `aqi_descriptor()` accept values above 500 (treated as
  Hazardous) and `NA`, and warn instead of erroring on negative values.
  Real AirNow data exceeds 500 during smoke events.
* Unrecognised pollutant or category names now warn instead of silently
  becoming `NA`.

```

- [ ] **Step 3: Update the pkgdown reference index**

Replace the whole of `_pkgdown.yml` with:

```yaml
url: https://briandconnelly.github.io/airnow/
template:
  bootstrap: 5
reference:
- title: Managing your AirNow API key
  desc: |
    An API key allows you to interact with the AirNow API.
    Keys can be created at [airnowapi.org](https://docs.airnowapi.org).
- contents:
  - set_airnow_key
  - get_airnow_key
- title: Retrieving air quality data
  desc: Current observations, forecasts, and monitor readings
- contents:
  - get_airnow_observations
  - get_airnow_forecasts
  - get_airnow_forecast_history
  - get_airnow_monitors
- title: Reporting areas
- contents:
  - get_airnow_reporting_area
  - airnow_areas
- title: AQI values
  desc: Convert AQI values to color or text representations
- contents:
  - aqi_color
  - aqi_descriptor
- title: Deprecated
- contents:
  - airnow-deprecated
```

Run: `Rscript -e 'pkgdown::check_pkgdown()'` (install pkgdown first with `install.packages("pkgdown", repos = "https://cloud.r-project.org")` if it is missing).
Expected: no error about topics missing from the index.

- [ ] **Step 4: Update the README source**

In `README.Rmd`:

- Line 45: change `## Creating an API Token` to `## Creating an API Key`.
- Line 48: change `The \`set_airnow_token()\` function can be used to help you create and configure your API token.` to `The \`set_airnow_key()\` function can be used to help you create and configure your API key.`
- Line 53: change `set_airnow_token()` to `set_airnow_key()`.
- Line 67: change `get_airnow_conditions(zip = "98101")` to `get_airnow_observations(zip = "98101")`.
- Line 77: change `get_airnow_area(` to `get_airnow_monitors(`.
- Insert after the Seattle example (after line 68's closing fence) a new subsection:

````markdown

### Tomorrow's forecast for Napa, by reporting area

Every location belongs to an AirNow *reporting area*. The bundled `airnow_areas` table lists them, and `get_airnow_reporting_area()` finds the one for a ZIP code or coordinate pair.

```{r}
get_airnow_reporting_area(zip = "94558")

get_airnow_forecasts(area = "ca064")
```
````

Then regenerate the rendered README (this evaluates the examples, so it needs the real key):

```bash
AIRNOW_API_KEY="$AIRNOW_API_TOKEN" Rscript -e 'devtools::build_readme()'
grep -n "airnow_token\|get_airnow_conditions\|get_airnow_area(" README.md || echo "README clean"
grep -c "$AIRNOW_API_TOKEN" README.md
```
Expected: `README clean` and `0`.

- [ ] **Step 5: Update cran-comments.md**

Replace its contents with:

```markdown
## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes for CRAN

This release migrates the package to AirNow's replacement web services.
AirNow retires the services used by the previous version on 2026-09-30,
after which two of its exported functions stop working. Those functions
are kept as deprecated wrappers around the new ones.

Tests use recorded HTTP fixtures (httptest2) and make no network requests.
```

- [ ] **Step 6: Full check and lint**

Run:
```bash
Rscript -e 'devtools::document()'
AIRNOW_API_KEY=test-key Rscript -e 'devtools::check(document = FALSE, error_on = "never")' 2>&1 | tail -40
Rscript -e 'lints <- lintr::lint_package(); print(lints); cat("lint count:", length(lints), "\n")'
```
Expected: `0 errors ✔ | 0 warnings ✔ | 0 notes ✔`, and `lint count: 0`. Common causes of a note and their fixes:
- `no visible binding for global variable`: some code uses a bare column or dataset name; use `areas_table()` or `x[["col"]]`.
- `Undocumented arguments`: a new function's roxygen is missing a `@param`; add it.
- `checking for future file timestamps ... unable to verify current time`: environmental, acceptable.

Adjust `cran-comments.md` if the note count is not zero, so it tells the truth.

- [ ] **Step 7: Run the scan the CI step will run, then commit**

```bash
pattern='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
grep -rliE "$pattern" tests/testthat --include='*.json' --include='*.R' --exclude='test-*.R' --exclude='helper-*.R' --exclude='setup.R' || echo "scan clean"
grep -rlF "$AIRNOW_API_TOKEN" . --exclude-dir=.git && echo "KEY LEAKED" || echo "no key anywhere in the tree"
git add DESCRIPTION NEWS.md _pkgdown.yml README.Rmd README.md cran-comments.md man/ NAMESPACE
git status --short
git commit -m "$(cat <<'EOF'
docs: document airnow 0.2.0 and bump the version

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```
Expected: `scan clean`, `no key anywhere in the tree`, and a clean `git status` after the commit. If `man/figures/` gained README figures, add them too.

- [ ] **Step 8: Report**

State verbatim: the `devtools::check()` summary line, the lint count, the total test count from the full `devtools::test()` run, and the list of mock directories under `tests/testthat/`. Remind the maintainer of the two manual actions the spec still needs before submission: run `docs/superpowers/probes/probe_midnight.sh` between 00:00 and 00:59 Pacific and, if the captured date behaviour contradicts the assumption in `observations_to_legacy()`, change the `date[wrap] <- date[wrap] - 1L` line and its test; and re-probe `/aq/forecast/historical/` for a future validity date after an afternoon issuance (spec section 2.3). Submission to CRAN is the maintainer's call: `devtools::release()` or `devtools::submit_cran()`.
