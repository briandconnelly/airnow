# AirNow API Migration, Plan 1 of 2: Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put in place everything the new retrieval functions depend on: safe transport, error handling, the `key` credential vocabulary, an AQI helper that tolerates real data, the bundled `airnow_areas` dataset, and the value-normalization helpers.

**Architecture:** This plan touches no public retrieval function beyond switching them to HTTPS and the new credential default. Every helper it adds is internal, pure where possible, and unit-tested with in-memory data so no network is needed. Plan 2 (`2026-09-12-airnow-migration-2-retrieval.md`) builds the new functions and compatibility shims on top of these interfaces.

**Tech Stack:** R (>= 4.1), httr2, jsonlite, tibble, cli, rlang, lifecycle, testthat 3e, devtools/roxygen2, usethis.

**Spec:** `dev/superpowers/specs/2026-09-09-airnow-api-migration-design.md` (sections 2, 4.3, 5, 6, 9, 10, 11). Read it before starting; every task below cites the section it implements.

## Global Constraints

- Repository root is `/Users/bdc/projects/airnow`. Run every command from there. Do not touch `/Users/bdc/Documents/Projects/airnow` (a stale checkout).
- R package conventions: `cli::cli_abort()` for errors, `cli::cli_warn()` for warnings, rlang predicates (`is_string()`, `is_logical()`, `is_integerish()`) for validation. The package `@import`s rlang, so call rlang functions unqualified.
- Keep lines under 80 characters, or append `# nolint` to a line that cannot be shortened (existing style). CI runs lintr.
- No new `Imports:`. `httptest2` is added to `Suggests:` in Plan 2, not here.
- Do not print, log, echo, or commit the API key. The real key is in the shell variable `AIRNOW_API_TOKEN`. When a step needs live network access, prefix the command with `AIRNOW_API_KEY="$AIRNOW_API_TOKEN"`. Nothing in this plan requires that except Task 5's download, which is a public file and needs no key.
- Tests: `Rscript -e 'devtools::test(filter = "<name>")'` runs `tests/testthat/test-<name>.R`. `Rscript -e 'devtools::test()'` runs everything. Expected output format is testthat's summary line, e.g. `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 12 ]`.
- Regenerate documentation with `Rscript -e 'devtools::document()'` whenever you add or change roxygen comments or exports. Commit the resulting `NAMESPACE` and `man/` changes with the code.
- Commits use conventional-commit prefixes (`feat:`, `fix:`, `test:`, `chore:`, `docs:`). End every commit message with these two lines:

  ```
  🤖 Generated with Claude Code
  Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
  ```

- Never report a check you did not run. If a command's output does not match the "Expected" line, stop and fix before moving on.

---

### Task 1: Repository housekeeping and evidence backup

Implements spec sections 10 ("One CRAN submission") and 11 ("must stop being machine-local"). No R code. Do this first: the `old/` probe payloads cannot be re-captured after 2026-09-30.

**Files:**
- Modify: `.gitignore`
- Modify: `.Rbuildignore` (already has an uncommitted line)
- Delete: `CRAN-SUBMISSION`
- Create: `dev/superpowers/probes/probe_midnight.sh`

- [ ] **Step 1: Confirm the current state**

Run:
```bash
git status --short
git check-ignore -v dev/superpowers/specs/2026-09-09-airnow-api-migration-design.md
```
Expected: `git status` shows ` M .Rbuildignore` and `?? CRAN-SUBMISSION`. `check-ignore` prints `.gitignore:4:docs	dev/superpowers/specs/...` (the spec is ignored).

- [ ] **Step 2: Confirm no credential is in the directory you are about to commit**

Run:
```bash
grep -rliE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' dev/superpowers/ || echo "no key-shaped strings"
```
Expected: the only line printed is `dev/superpowers/probes/probe.sh`. That match is a session UUID inside a scratchpad path on line 3, not a key (verified 2026-09-12). If any other file is listed, stop and report it.

- [ ] **Step 3: Change the ignore rule so the subdirectory can be tracked**

Git cannot re-include a subdirectory of an ignored directory, so `docs` must become `docs/*`. Replace the line `docs` in `.gitignore` with two lines:

```
docs/*
!dev/superpowers/
```

Run:
```bash
python3 - <<'EOF'
p = ".gitignore"
s = open(p).read()
assert "\ndocs\n" in s
s = s.replace("\ndocs\n", "\ndocs/*\n!dev/superpowers/\n")
open(p, "w").write(s)
EOF
git check-ignore -v dev/superpowers/specs/2026-09-09-airnow-api-migration-design.md || echo "spec is now tracked-able"
git check-ignore -v docs/index.html || echo "WARNING: docs/index.html would be tracked"
```
Expected: first command prints `spec is now tracked-able`. Second prints `.gitignore:...:docs/*	docs/index.html` (pkgdown output stays ignored).

- [ ] **Step 4: Write the midnight probe script**

The spec (section 5.1) needs a real response captured between 00:00 and 00:59 local time in some reporting area, from both the old and new services. Create `dev/superpowers/probes/probe_midnight.sh`:

```bash
#!/bin/bash
# Capture paired old/new observation responses for the midnight-wrap question
# (spec section 5.1). Run between 00:00 and 00:59 in the reporting area's local
# time. Zip 90210 is Pacific time; run at 00:xx PDT/PST. Repeat for another
# timezone if convenient (e.g. zip 10001, Eastern).
#
# Usage: AIRNOW_API_TOKEN=... ./probe_midnight.sh [zip]
set -euo pipefail
KEY="${AIRNOW_API_TOKEN:?AIRNOW_API_TOKEN not set}"
ZIP="${1:-90210}"
STAMP="$(date +%Y-%m-%dT%H%M%S%z)"
HERE="$(cd "$(dirname "$0")" && pwd)"
B=https://www.airnowapi.org

curl -sS -G "$B/aq/observation/zipCode/current/" \
  --data-urlencode format=application/json \
  --data-urlencode "api_key=$KEY" -d "zipCode=$ZIP" \
  -o "$HERE/old/observation_zipCode_current__midnight_${STAMP}.json" &
curl -sS -G "$B/aq/observation/current/ziplatLong" \
  --data-urlencode format=application/json \
  --data-urlencode "api_key=$KEY" -d "zipCode=$ZIP" \
  -o "$HERE/new/observation_current_ziplatLong__midnight_${STAMP}.json" &
wait

for f in "$HERE"/old/*midnight_${STAMP}.json "$HERE"/new/*midnight_${STAMP}.json; do
  if grep -q "$KEY" "$f"; then echo "KEY LEAKED into $f"; exit 1; fi
  printf '%s: ' "$(basename "$f")"; head -c 200 "$f"; echo
done
echo "Look for HourObserved (old) vs hourObserved (new) and the two dates."
```

Run:
```bash
chmod +x dev/superpowers/probes/probe_midnight.sh
bash -n dev/superpowers/probes/probe_midnight.sh && echo "syntax ok"
```
Expected: `syntax ok`.

- [ ] **Step 5: Remove the stale CRAN-SUBMISSION file and commit everything**

`CRAN-SUBMISSION` records the 0.1.1 submission that CRAN published on 2026-03-01. It is a leftover, not an in-flight submission (spec section 8, question 2).

Run:
```bash
rm CRAN-SUBMISSION
git add .gitignore .Rbuildignore dev/superpowers/
git status --short | head -40
```
Expected: `.gitignore`, `.Rbuildignore`, the spec, the two plan files, `dev/superpowers/probes/README.md`, `probe.sh`, `probe_midnight.sh`, `reportingarea_metadata.dat`, and every file under `probes/new/` and `probes/old/` are staged as `A`. `CRAN-SUBMISSION` is untracked so it simply disappears.

```bash
git commit -m "$(cat <<'EOF'
chore: track migration spec and probe evidence; drop stale CRAN-SUBMISSION

The old-service probe payloads cannot be re-captured after 2026-09-30.
docs/ stays ignored except dev/superpowers/.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

- [ ] **Step 6: Tell the maintainer about the probe**

In your task report, state that `dev/superpowers/probes/probe_midnight.sh` exists and must be run by a person between 00:00 and 00:59 Pacific time before 2026-09-30. It cannot be automated from this plan.

---

### Task 2: HTTPS transport and error-aware response handling

Implements spec sections 2.2 (HTTPS), 2.3 ("No data" envelope), and 6 ("Error handling").

**Files:**
- Modify: `R/api.R`
- Modify: `tests/testthat/test-api.R`

**Interfaces:**
- Produces: `req_airnow(throttle_rate)` now returns an `httr2_request` whose base URL is `https://www.airnowapi.org/aq` and which carries an `httr2::req_error()` body handler.
- Produces: `perform_airnow(req)` performs the request and returns a tibble. It returns a zero-column, zero-row tibble for the API's "no data" replies, aborts with the API's message for any other `WebServiceError`, and returns `tibble::as_tibble(jsonlite::fromJSON(body, flatten = TRUE))` otherwise. Plan 2 calls this from every retrieval function.
- Produces: `resp_airnow_tibble(resp)` (the parsing half of `perform_airnow()`, exposed for testing) and `airnow_error_messages(resp)` (extracts `Message` strings from a `WebServiceError` body, or `NULL`).

- [ ] **Step 1: Write the failing tests**

Replace the whole of `tests/testthat/test-api.R` with:

```r
test_that("req_airnow() catches invalid inputs", {
  expect_error(req_airnow(throttle_rate = NULL))
  expect_error(req_airnow(throttle_rate = -1))
  expect_error(req_airnow(throttle_rate = NA_real_))
})

test_that("req_airnow() uses HTTPS", {
  result <- req_airnow()
  expect_s3_class(result, "httr2_request")
  expect_equal(result$url, "https://www.airnowapi.org/aq")
})

test_that("airnow_error_messages() extracts messages from the error envelope", {
  resp <- httr2::response_json(
    status_code = 401,
    body = list(WebServiceError = list(list(Message = "Request not authenticated.")))
  )
  expect_equal(airnow_error_messages(resp), "Request not authenticated.")

  plain <- httr2::response_json(status_code = 200, body = list(list(aqi = 1)))
  expect_null(airnow_error_messages(plain))

  not_json <- httr2::response(status_code = 500, body = charToRaw("oops"))
  expect_null(airnow_error_messages(not_json))
})

test_that("resp_airnow_tibble() parses a normal payload", {
  resp <- httr2::response_json(
    status_code = 200,
    body = list(list(aqi = 53L, parameterName = "PM2.5"))
  )
  result <- resp_airnow_tibble(resp)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$parameterName, "PM2.5")
})

test_that("resp_airnow_tibble() returns an empty tibble for empty arrays", {
  resp <- httr2::response_json(status_code = 200, body = list())
  result <- resp_airnow_tibble(resp)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("resp_airnow_tibble() treats 'no data' errors as empty results", {
  msgs <- c(
    "There are no observations available for the requested latitude/longitude: No observations were found for all monitors within 50 miles.", # nolint
    "Error - There is no reporting area at your searched location"
  )
  for (msg in msgs) {
    resp <- httr2::response_json(
      status_code = 200,
      body = list(WebServiceError = list(list(Message = msg)))
    )
    result <- resp_airnow_tibble(resp)
    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 0)
  }
})

test_that("resp_airnow_tibble() aborts with the API message for other errors", {
  resp <- httr2::response_json(
    status_code = 200,
    body = list(WebServiceError = list(list(Message = "Invalid date format.")))
  )
  expect_error(resp_airnow_tibble(resp), "Invalid date format")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "api")'`
Expected: failures mentioning `could not find function "airnow_error_messages"` and the HTTPS assertion failing with `http://`.

- [ ] **Step 3: Implement**

Replace the whole of `R/api.R` with:

```r
#' Create a Request for the AirNow API
#'
#' The AirNow API enforces [rate limits](https://docs.airnowapi.org/faq#rateLimits). # nolint
#' For most endpoints, this is 500 requests per hour.
#'
#' @param throttle_rate Numeric value indicating the maximum number of requests
#'   per second.
#'
#' @return An [httr2::request] object
#' @noRd
#'
req_airnow <- function(throttle_rate = 500 / 3600) {
  if (!is_double(throttle_rate, n = 1) || throttle_rate < 0) {
    cli::cli_abort("{.arg throttle_rate} must be a positive number")
  }

  httr2::request("https://www.airnowapi.org/aq") |>
    httr2::req_user_agent(glue("airnow v{packageVersion('airnow')} <https://github.com/briandconnelly/airnow>")) |> # nolint
    httr2::req_throttle(rate = throttle_rate) |>
    httr2::req_error(body = airnow_error_messages)
}

#' Extract AirNow error messages from a response
#'
#' AirNow reports problems as `{"WebServiceError":[{"Message":"..."}]}`,
#' under a 200 for "no data" and under 4xx for other failures.
#'
#' @param resp An [httr2::response] object
#' @return A character vector of messages, or `NULL` if the body is not an
#'   AirNow error envelope.
#' @noRd
airnow_error_messages <- function(resp) {
  text <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
  parsed <- tryCatch(jsonlite::fromJSON(text), error = function(e) NULL)
  if (is.list(parsed) && !is.data.frame(parsed) &&
    !is.null(parsed$WebServiceError)) {
    as.character(parsed$WebServiceError$Message)
  } else {
    NULL
  }
}

# Messages the API uses to say "nothing matched", which are not errors.
airnow_no_data_pattern <- "^(Error - )?There (are|is) no "

#' Convert an AirNow response into a tibble
#'
#' @param resp An [httr2::response] object with a JSON body
#' @return A tibble. Zero rows (and zero columns) when the API reports that no
#'   data matched the request.
#' @noRd
resp_airnow_tibble <- function(resp) {
  msgs <- airnow_error_messages(resp)
  if (!is.null(msgs)) {
    if (all(grepl(airnow_no_data_pattern, msgs))) {
      return(tibble::tibble())
    }
    cli::cli_abort(c(
      "The AirNow API returned an error:",
      set_names(msgs, rep("x", length(msgs)))
    ))
  }

  parsed <- resp |>
    httr2::resp_body_string() |>
    jsonlite::fromJSON(flatten = TRUE)

  tibble::as_tibble(parsed)
}

#' Perform an AirNow request and parse the result
#'
#' @param req An [httr2::request] built with [req_airnow()]
#' @return A tibble; see [resp_airnow_tibble()]
#' @noRd
perform_airnow <- function(req) {
  req |>
    httr2::req_perform() |>
    resp_airnow_tibble()
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `Rscript -e 'devtools::test(filter = "api")'`
Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 15 ]` (count may differ by one or two; what matters is FAIL 0).

- [ ] **Step 5: Commit**

```bash
git add R/api.R tests/testthat/test-api.R
git commit -m "$(cat <<'EOF'
fix: use HTTPS for the AirNow API and surface WebServiceError messages

The API 301-redirects http:// to https://, so the key was making its first
hop in plaintext. perform_airnow() now turns the API's error envelope into
an empty tibble ("no data") or a cli error with the API's own message.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 3: Credentials renamed to "key"; token functions deprecated

Implements spec section 6 ("Credentials") and part of section 5 (two of the five deprecated functions).

**Files:**
- Modify: `R/credentials.R` (rewrite)
- Create: `R/deprecated.R`
- Modify: `R/get_airnow_conditions.R:32`, `R/get_airnow_forecast.R:27`, `R/get_airnow_area.R:42` and `:101`
- Modify: `tests/testthat/test-credentials.R` (rewrite)

**Interfaces:**
- Produces: `get_airnow_key(ask = is_interactive())` returns the key string or aborts. `set_airnow_key(key = NULL, ask = is_interactive())` sets `AIRNOW_API_KEY` for the session and returns the key invisibly. `airnow_key_isset()` is `TRUE` when the variable is set to a non-empty string.
- Produces: `get_airnow_token()` and `set_airnow_token()` remain exported, emit a `lifecycle` deprecation warning, and delegate to the key functions. `R/deprecated.R` is where Plan 2 adds the remaining three shims.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `tests/testthat/test-credentials.R` with:

```r
test_that("key functions work when the variable is set", {
  test_key <- "00000000-0000-4000-8000-000000000000"
  withr::local_envvar(AIRNOW_API_KEY = test_key)

  expect_true(airnow_key_isset())
  expect_equal(get_airnow_key(ask = FALSE), test_key)

  new_key <- "123-new-key"
  expect_message(set_airnow_key(key = new_key, ask = FALSE))
  expect_true(airnow_key_isset())
  expect_equal(get_airnow_key(ask = FALSE), new_key)
})

test_that("key functions work when the variable is not set", {
  withr::local_envvar(AIRNOW_API_KEY = NA)
  expect_false(airnow_key_isset())
  expect_error(get_airnow_key(ask = FALSE))

  test_key <- "00000000-0000-4000-8000-000000000000"
  expect_silent(set_airnow_key(key = test_key, ask = FALSE))
  expect_true(airnow_key_isset())
  expect_equal(get_airnow_key(ask = FALSE), test_key)
})

test_that("an empty string counts as unset", {
  withr::local_envvar(AIRNOW_API_KEY = "")
  expect_false(airnow_key_isset())
  expect_error(get_airnow_key(ask = FALSE))
})

test_that("set_airnow_key() rejects non-string keys", {
  withr::local_envvar(AIRNOW_API_KEY = NA)
  expect_error(set_airnow_key(key = 123, ask = FALSE))
  expect_error(set_airnow_key(key = "", ask = FALSE))
  expect_error(set_airnow_key(key = c("a", "b"), ask = FALSE))
})

test_that("token functions are deprecated aliases for the key functions", {
  withr::local_envvar(AIRNOW_API_KEY = "abc")

  lifecycle::expect_deprecated(result <- get_airnow_token(ask = FALSE))
  expect_equal(result, "abc")

  lifecycle::expect_deprecated(
    suppressMessages(set_airnow_token(token = "def", ask = FALSE))
  )
  expect_equal(Sys.getenv("AIRNOW_API_KEY"), "def")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "credentials")'`
Expected: failures with `could not find function "airnow_key_isset"` and similar.

- [ ] **Step 3: Rewrite `R/credentials.R`**

Replace the whole file with:

```r
#' Manage your AirNow API key
#'
#' @description `get_airnow_key()` returns the configured AirNow API key. If
#'   no key is set and `ask` is `TRUE` in an interactive session, you are
#'   prompted for one; otherwise an error is raised.
#'
#' The key is read from the `AIRNOW_API_KEY` environment variable. To set it
#' permanently, add `AIRNOW_API_KEY=your-key` to your `~/.Renviron` file.
#' Keys are issued at <https://docs.airnowapi.org/account/request/>.
#'
#' @param ask Whether to prompt for the key if none is set. Prompting only
#'   works in interactive sessions.
#'
#' @return `get_airnow_key()` returns a string.
#' @export
#'
#' @examples
#' \dontrun{
#' get_airnow_key()
#' }
get_airnow_key <- function(ask = is_interactive()) {
  if (!airnow_key_isset()) {
    set_airnow_key(ask = ask)
  }
  Sys.getenv("AIRNOW_API_KEY")
}


#' @rdname get_airnow_key
#' @description `set_airnow_key()` sets the AirNow API key for the current
#'   session.
#' @param key The API key to use. If `NULL` and `ask` is `TRUE`, you are
#'   prompted for one.
#' @return `set_airnow_key()` returns the key, invisibly.
#' @export
#' @examples
#' \dontrun{
#' set_airnow_key(key = "4d36e978-e325-11ce-bfc1-08002be10318")
#' }
set_airnow_key <- function(key = NULL, ask = is_interactive()) {
  if (is.null(key)) {
    if (ask && is_interactive()) {
      cli::cli_alert_info("Your AirNow API key is not set. Visit {.url https://docs.airnowapi.org/account/request/} to create an account.") # nolint
      key <- readline("Please enter your API key: ")
    } else {
      cli::cli_abort("Set your AirNow API key by providing {.arg key} or by setting {.envvar AIRNOW_API_KEY} in your {.file ~/.Renviron} file.") # nolint
    }
  } else if (airnow_key_isset()) {
    cli::cli_alert_info("AirNow API key is already set. Overriding for this session only.\nTo use this key permanently, update {.envvar AIRNOW_API_KEY} in your {.file ~/.Renviron} file.") # nolint
  }

  if (!is_string(key) || !nzchar(key)) {
    cli::cli_abort("{.arg key} must be a non-empty string")
  }

  Sys.setenv(AIRNOW_API_KEY = key)
  invisible(key)
}


airnow_key_isset <- function() {
  nzchar(Sys.getenv("AIRNOW_API_KEY", unset = ""))
}
```

- [ ] **Step 4: Create `R/deprecated.R` with the token shims**

```r
#' Deprecated functions
#'
#' @description These functions were deprecated in airnow 0.2.0 and will be
#'   removed in a future release. Each one warns and then calls its
#'   replacement.
#'
#' | Deprecated | Replacement |
#' |---|---|
#' | `get_airnow_token()` | [get_airnow_key()] |
#' | `set_airnow_token()` | [set_airnow_key()] |
#'
#' @name airnow-deprecated
#' @keywords internal
NULL


#' @rdname airnow-deprecated
#' @inheritParams get_airnow_key
#' @export
get_airnow_token <- function(ask = is_interactive()) {
  lifecycle::deprecate_warn("0.2.0", "get_airnow_token()", "get_airnow_key()")
  get_airnow_key(ask = ask)
}


#' @rdname airnow-deprecated
#' @param token The API key to use (deprecated spelling of `key`)
#' @export
set_airnow_token <- function(token = NULL, ask = is_interactive()) {
  lifecycle::deprecate_warn("0.2.0", "set_airnow_token()", "set_airnow_key()")
  set_airnow_key(key = token, ask = ask)
}
```

- [ ] **Step 5: Point the retrieval functions at the new default**

Run:
```bash
sed -i '' 's/api_key = get_airnow_token()/api_key = get_airnow_key()/' \
  R/get_airnow_conditions.R R/get_airnow_forecast.R
# get_airnow_area.R has two occurrences: the signature default (keep the
# default) and a bug on line ~101 that ignores the api_key argument.
sed -i '' 's/api_key = get_airnow_token()) {/api_key = get_airnow_key()) {/' R/get_airnow_area.R
sed -i '' 's/      api_key = get_airnow_token(),/      api_key = api_key,/' R/get_airnow_area.R
grep -n "airnow_token\|api_key = " R/get_airnow_conditions.R R/get_airnow_forecast.R R/get_airnow_area.R
```
Expected: no line mentions `get_airnow_token`. `get_airnow_area.R` shows `api_key = get_airnow_key()) {` in the signature and `api_key = api_key,` inside the query.

- [ ] **Step 6: Regenerate docs and run the tests**

Run:
```bash
Rscript -e 'devtools::document()'
Rscript -e 'devtools::test(filter = "credentials")'
grep -n "get_airnow_key\|set_airnow_key\|get_airnow_token\|set_airnow_token" NAMESPACE
```
Expected: `[ FAIL 0 | ... ]`. NAMESPACE exports all four functions.

- [ ] **Step 7: Run the whole suite to make sure nothing else broke**

Run: `Rscript -e 'devtools::test()'`
Expected: `FAIL 0`. Network-backed tests skip (they check for an empty `AIRNOW_API_KEY`); that is fine for now.

- [ ] **Step 8: Commit**

```bash
git add R/credentials.R R/deprecated.R R/get_airnow_conditions.R \
  R/get_airnow_forecast.R R/get_airnow_area.R NAMESPACE man/ \
  tests/testthat/test-credentials.R
git commit -m "$(cat <<'EOF'
feat: rename credential helpers to get_airnow_key()/set_airnow_key()

Matches the API's own vocabulary and the AIRNOW_API_KEY variable. The
token-named functions remain as deprecated aliases. Also fixes
get_airnow_area() ignoring its api_key argument.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 4: AQI helpers accept real-world values

Implements spec section 9 exactly as tabulated there. This deliberately changes the existing contract.

**Files:**
- Modify: `R/argument_checks.R:85-90` (`check_aqi()`)
- Modify: `R/aqi.R`
- Modify: `tests/testthat/test-aqi.R`
- Modify: `tests/testthat/test-argument_checks.R` (the two `check_aqi` blocks at the end)

**Interfaces:**
- Produces: `check_aqi(x, arg_name = "aqi")` returns an integer vector the same length as `x`. Negative values become `NA` with a warning; `NA` passes silently; non-numeric, `NULL`, or zero-length input aborts.
- Produces: `aqi_color(aqi)` and `aqi_descriptor(aqi)` return `NA` where the input is `NA` and the Hazardous value for anything above 500.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `tests/testthat/test-aqi.R` with:

```r
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
```

In `tests/testthat/test-argument_checks.R`, replace the two `check_aqi` blocks at the end of the file (from `test_that("check_aqi() catches invalid input", {` to the end) with:

```r
test_that("check_aqi() rejects non-numeric input", {
  expect_error(check_aqi(NULL))
  expect_error(check_aqi(c()))
  expect_error(check_aqi("35"))
  expect_error(check_aqi(1.5))
  expect_error(check_aqi(20, 30, -1))
  expect_error(check_aqi(20, 30, NULL))
})

test_that("check_aqi() returns integers, clamps nothing, and tolerates NA", {
  valid_aqi <- as.integer(runif(100, min = 0, max = 500))
  for (i in valid_aqi) {
    expect_equal(check_aqi(i), i)
  }
  expect_equal(check_aqi(874), 874L)
  expect_equal(check_aqi(NA_integer_), NA_integer_)
  expect_equal(check_aqi(NA), NA_integer_)
  expect_equal(check_aqi(c(1, NA, 3)), c(1L, NA, 3L))
})

test_that("check_aqi() warns on negatives and replaces them with NA", {
  expect_warning(result <- check_aqi(-1), "-1")
  expect_equal(result, NA_integer_)
  expect_warning(result <- check_aqi(c(10, -7)), "negative")
  expect_equal(result, c(10L, NA))
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "aqi|argument_checks")'`
Expected: failures on the clamp, NA, and negative tests (they currently error).

- [ ] **Step 3: Implement `check_aqi()`**

In `R/argument_checks.R`, replace the `check_aqi` function (the last function in the file) with:

```r
check_aqi <- function(x, arg_name = "aqi") {
  # A bare logical NA (e.g. `NA`) is a legitimate missing value
  if (is.logical(x) && length(x) > 0 && all(is.na(x))) {
    x <- as.integer(x)
  }

  if (length(x) == 0 || !is_integerish(x)) {
    cli::cli_abort("{.arg {arg_name}} must be a vector of whole numbers")
  }

  x <- as.integer(x)
  negative <- !is.na(x) & x < 0

  if (any(negative & x == -1)) {
    cli::cli_warn("{.arg {arg_name}} contains -1, the AirNow sentinel for a categorical forecast; returning {.val NA} for those values") # nolint
  }
  if (any(negative & x != -1)) {
    cli::cli_warn("{.arg {arg_name}} contains negative values; returning {.val NA} for those values") # nolint
  }
  x[negative] <- NA_integer_

  x
}
```

- [ ] **Step 4: Implement the helpers**

Replace the whole of `R/aqi.R` with:

```r
#' @rdname aqi
#' @title Label AQI Values
#'
#' @description `aqi_color()` returns the color that corresponds with the given
#' AQI value.
#'
#' @details The AQI scale nominally tops out at 500, but AirNow reports
#'   higher values during severe smoke events. Values above 500 are treated
#'   as Hazardous. `NA` inputs give `NA` outputs. Negative values (including
#'   AirNow's `-1` sentinel for a categorical forecast) give `NA` with a
#'   warning.
#'
#' @param aqi A vector of AQI values (whole numbers, `NA` allowed)
#'
#' @return `aqi_color()` returns a character vector of RGB hex strings
#' @export
#'
#' @examples
#' aqi_color(35)
#' aqi_color(c(35, NA, 874))
aqi_color <- function(aqi) {
  aqi <- check_aqi(aqi)

  colors <- rep(
    c("#00E400", "#FFFF00", "#FF7E00", "#FF0000", "#8F3F97", "#7E0023"),
    c(51, 50, 50, 50, 100, 200)
  )

  colors[pmin(aqi, 500L) + 1L]
}


#' @rdname aqi
#' @description `aqi_descriptor()` converts the given AQI value(s) into a
#'   descriptive string.
#' @return `aqi_descriptor()` returns a character vector
#' @export
#' @examples
#' aqi_descriptor(35)
aqi_descriptor <- function(aqi) {
  aqi <- check_aqi(aqi)

  descriptors <- rep(
    c(
      "Good",
      "Moderate",
      "Unhealthy for Sensitive Groups",
      "Unhealthy",
      "Very Unhealthy",
      "Hazardous"
    ),
    c(51, 50, 50, 50, 100, 200)
  )

  descriptors[pmin(aqi, 500L) + 1L]
}
```

Why this works: `pmin(NA, 500L)` is `NA`, and indexing a vector with `NA` returns `NA`. `pmin(874L, 500L) + 1L` is `501`, the last element.

- [ ] **Step 5: Run the tests to confirm they pass**

Run:
```bash
Rscript -e 'devtools::document()'
Rscript -e 'devtools::test(filter = "aqi|argument_checks")'
```
Expected: `FAIL 0`.

- [ ] **Step 6: Commit**

```bash
git add R/aqi.R R/argument_checks.R man/aqi.Rd \
  tests/testthat/test-aqi.R tests/testthat/test-argument_checks.R
git commit -m "$(cat <<'EOF'
fix: let aqi_color() and aqi_descriptor() handle values above 500 and NA

Real AirNow data exceeds 500 during smoke events (874 observed in Portland,
2020-09-13). Values above 500 are now Hazardous; NA passes through; negative
values, including the -1 categorical-forecast sentinel, warn and become NA.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 5: The `airnow_areas` dataset

Implements spec sections 2.6 and 6 ("`airnow_areas`"). Verified facts about the source file (2026-09-12): 1,037 lines, no header, 14 pipe-separated fields, CRLF line endings, one exact duplicate row (Monterrey, `mx002`), 68 rows with an empty last field, one row with an empty third field, one non-ASCII row (Guanajuato, `mx004`), every area code matches `^[a-z]{2}[0-9]{3}$`. After removing the duplicate: 1,036 rows, 26 distinct reporting-area names that appear more than once (30 extra rows in total).

**Files:**
- Create: `data-raw/airnow_areas.R`
- Create: `data/airnow_areas.rda` (generated)
- Create: `R/data.R`
- Create: `tests/testthat/test-data.R`
- Modify: `DESCRIPTION` (add `LazyData: true`)
- Modify: `.Rbuildignore` (add `^data-raw$`)

**Interfaces:**
- Produces: exported dataset `airnow_areas`, a tibble with 1,036 rows and these 14 columns in this order and type: `reporting_area` (chr), `state_code` (chr), `country_code` (chr), `latitude` (dbl), `longitude` (dbl), `gmt_offset` (int), `observes_dst` (lgl), `tz_standard` (chr), `tz_daylight` (chr), `reporting_area_code` (chr), `agency` (chr), `lookup_behavior` (chr), `considered_monitors` (chr), `lookup_boundary` (chr, `NA` when blank).
- Produces: internal accessor `areas_table()` returning that tibble. **All package code must go through `areas_table()`**, never the bare name, so the dataset resolves whether or not the package is attached.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-data.R`:

```r
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
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "data")'`
Expected: failures with `could not find function "areas_table"`.

- [ ] **Step 3: Write the build script**

Create `data-raw/airnow_areas.R`:

```r
# Build the `airnow_areas` dataset from AirNow's reporting-area metadata file.
#
# Run from the package root with:
#   Rscript data-raw/airnow_areas.R
#
# The file is public (no key needed), pipe-delimited, has no header, uses
# CRLF line endings, contains one exact duplicate row (Monterrey, mx002),
# and one non-ASCII row (Guanajuato). read.delim() handles CRLF on every
# platform; strsplit() must NOT be used because it drops trailing empty
# fields (68 rows have an empty last field).

url <- "https://files.airnowtech.org/airnow/today/reportingarea_metadata.dat"

raw <- utils::read.delim(
  url,
  sep = "|",
  header = FALSE,
  quote = "",
  comment.char = "",
  na.strings = "",
  colClasses = "character",
  encoding = "UTF-8",
  stringsAsFactors = FALSE
)

stopifnot(ncol(raw) == 14)

names(raw) <- c(
  "reporting_area", "state_code", "country_code", "latitude", "longitude",
  "gmt_offset", "observes_dst", "tz_standard", "tz_daylight",
  "reporting_area_code", "agency", "lookup_behavior",
  "considered_monitors", "lookup_boundary"
)

# Defensive: strip any carriage return that survived, then mark encoding.
for (col in names(raw)) {
  raw[[col]] <- sub("\r$", "", raw[[col]])
  raw[[col]] <- enc2utf8(raw[[col]])
}

raw <- raw[!duplicated(raw), ]
stopifnot(anyDuplicated(raw$reporting_area_code) == 0)
stopifnot(all(grepl("^[a-z]{2}[0-9]{3}$", raw$reporting_area_code)))
stopifnot(all(raw$observes_dst %in% c("Yes", "No")))

airnow_areas <- tibble::tibble(
  reporting_area = raw$reporting_area,
  state_code = raw$state_code,
  country_code = raw$country_code,
  latitude = as.numeric(raw$latitude),
  longitude = as.numeric(raw$longitude),
  gmt_offset = as.integer(raw$gmt_offset),
  observes_dst = raw$observes_dst == "Yes",
  tz_standard = raw$tz_standard,
  tz_daylight = raw$tz_daylight,
  reporting_area_code = raw$reporting_area_code,
  agency = raw$agency,
  lookup_behavior = raw$lookup_behavior,
  considered_monitors = raw$considered_monitors,
  lookup_boundary = raw$lookup_boundary
)

stopifnot(!anyNA(airnow_areas$latitude), !anyNA(airnow_areas$longitude))
stopifnot(!anyNA(airnow_areas$gmt_offset))

message("Rows: ", nrow(airnow_areas), " (expected 1036 as of 2026-09-12)")

usethis::use_data(airnow_areas, overwrite = TRUE)
```

- [ ] **Step 4: Run the build script and register the data directory**

Run:
```bash
Rscript data-raw/airnow_areas.R
ls -la data/
grep -q '^\^data-raw\$$' .Rbuildignore || echo '^data-raw$' >> .Rbuildignore
grep -q '^LazyData:' DESCRIPTION || printf 'LazyData: true\n' >> DESCRIPTION
tail -3 DESCRIPTION; tail -3 .Rbuildignore
```
Expected: the script prints `Rows: 1036` and `✔ Saving "airnow_areas" to "data/airnow_areas.rda"`. `data/airnow_areas.rda` exists (roughly 30-60 KB). DESCRIPTION ends with `LazyData: true`. `.Rbuildignore` ends with `^data-raw$`.

If `use_data()` itself added `LazyData: true`, the `grep -q` guard prevents a duplicate line. Confirm with `grep -c '^LazyData' DESCRIPTION` printing `1`.

- [ ] **Step 5: Document the dataset and add the accessor**

Create `R/data.R`:

```r
#' AirNow reporting areas
#'
#' Metadata for every AirNow reporting area: its location, time zone, agency,
#' and the rules AirNow uses to pick monitors for it. Reporting-area codes
#' are the `area` argument to [get_airnow_observations()],
#' [get_airnow_forecasts()], and [get_airnow_forecast_history()].
#'
#' Reporting areas are occasionally added, renamed, or retired between
#' package releases, so a live response can name an area missing from this
#' table. Functions that join against it warn when that happens and leave
#' the geography columns `NA`.
#'
#' @format A tibble with 1,036 rows and 14 columns:
#' \describe{
#'   \item{reporting_area}{Area name. Not unique: 26 names appear in more
#'     than one state (e.g. Aberdeen, SD and Aberdeen, WA).}
#'   \item{state_code}{Two-letter state or province code}
#'   \item{country_code}{Two-letter country code (US, CA, MX)}
#'   \item{latitude, longitude}{Representative point, decimal degrees}
#'   \item{gmt_offset}{Standard-time offset from UTC, in hours}
#'   \item{observes_dst}{Whether the area observes daylight saving time}
#'   \item{tz_standard, tz_daylight}{Time zone abbreviations as AirNow
#'     records them. Some are non-standard (Anchorage: `AKT`/`ADT`).}
#'   \item{reporting_area_code}{Unique code, e.g. `"ca064"`}
#'   \item{agency}{Agency responsible for the area}
#'   \item{lookup_behavior}{How AirNow picks monitors, e.g.
#'     `"Closest Reading By Pollutant"`}
#'   \item{considered_monitors}{Which monitors are eligible}
#'   \item{lookup_boundary}{Search radius, e.g. `"50 miles"`; `NA` when
#'     AirNow leaves it blank}
#' }
#'
#' @source AirNow reporting area metadata,
#'   <https://files.airnowtech.org/airnow/today/reportingarea_metadata.dat>,
#'   retrieved 2026-09-12. AirNow is a partnership of the U.S. EPA, NOAA,
#'   NPS, tribal, state, and local agencies; the file is published without
#'   access restrictions. One exact duplicate row (Monterrey, `mx002`) was
#'   removed. Rebuild with `data-raw/airnow_areas.R`.
"airnow_areas"


# Package code must use this accessor rather than the bare dataset name so
# the lookup works whether or not the package is attached (lazy-loaded data
# lives in the package environment, not the namespace).
areas_table <- function() {
  airnow::airnow_areas
}
```

- [ ] **Step 6: Regenerate docs and run the tests**

Run:
```bash
Rscript -e 'devtools::document()'
Rscript -e 'devtools::test(filter = "data")'
```
Expected: `FAIL 0`.

- [ ] **Step 7: Prove the accessor works from an installed, unattached package**

Run:
```bash
R CMD INSTALL --no-multiarch --no-docs . > /dev/null 2>&1 && \
Rscript -e 'cat(nrow(airnow:::areas_table()), "\n")'
```
Expected: `1036`. If this errors with `object 'airnow_areas' not found`, change `areas_table()` to load a copy stored in the namespace instead: add `usethis::use_data(airnow_areas, internal = TRUE, overwrite = TRUE)` as the last line of the build script (this writes `R/sysdata.rda`), re-run the script, change the accessor body to just `airnow_areas`, and re-run this step. Report which variant you ended up with.

- [ ] **Step 8: Commit**

```bash
git add data-raw/airnow_areas.R data/airnow_areas.rda R/data.R \
  tests/testthat/test-data.R DESCRIPTION .Rbuildignore NAMESPACE man/
git commit -m "$(cat <<'EOF'
feat: bundle the airnow_areas reporting-area metadata dataset

1,036 reporting areas with location, time zone, agency, and lookup rules,
built from AirNow's public metadata file by data-raw/airnow_areas.R.
Needed to resolve area codes and geography for the 2026 web services.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 6: Value-normalization helpers and generic name cleaning

Implements spec section 4.3 (parameter and category factors, out-of-vocabulary warning, hour label, UTC derivation) and the "clean mechanical transform" for lowerCamelCase names.

**Files:**
- Create: `R/normalize.R`
- Create: `tests/testthat/test-normalize.R`
- Modify: `R/utils.R` (`clean_names()`)
- Modify: `tests/testthat/test-utils.R`

**Interfaces:**
- Produces: `parameter_levels`, a character constant `c("ozone", "pm2.5", "pm10", "co", "no2", "so2")`.
- Produces: `to_parameter_factor(x)` lowercases, maps `"o3"` to `"ozone"`, warns about unrecognised values, and returns an unordered factor on `parameter_levels`.
- Produces: `to_category_factor(x, ordered = TRUE)` returns a factor on `category_levels` (defined in `R/airnow-package.R`), warning about unrecognised values.
- Produces: `hour_label_to_integer(x)` turns `"18:00"` into `18L`; anything not matching `HH:MM` becomes `NA` with a warning; `NA` stays `NA` silently.
- Produces: `derive_utc_datetime(date, hour, tz_abbr, reporting_area_code)` returns a `POSIXct` (UTC) vector following the four-step rule in spec section 4.3.
- Produces: `clean_names(x)` now converts any unmapped lowerCamelCase name to snake_case, in addition to the explicit mapping table. New explicit entries: `parameterName -> parameter`, `reportingAreaName -> reporting_area`, `nowcastAQI -> aqi`, `aqiCategoryName -> category_name`, `dailyAQI -> aqi`, `dailyAQICategoryName -> category_name`, `siteID -> site_id`.

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-normalize.R`:

```r
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
```

Replace the whole of `tests/testthat/test-utils.R` with:

```r
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
  expect_equal(camel_to_snake("dailyAQICategoryName"), "daily_aqi_category_name")
  expect_equal(camel_to_snake("siteID"), "site_id")
  expect_equal(camel_to_snake("already_snake"), "already_snake")
})
```

- [ ] **Step 2: Run the tests to confirm they fail**

Run: `Rscript -e 'devtools::test(filter = "normalize|utils")'`
Expected: failures with `could not find function "to_parameter_factor"` and the generic-conversion test failing.

- [ ] **Step 3: Implement `R/normalize.R`**

```r
# Canonical pollutant names. The API spells ozone three ways (OZONE, Ozone,
# O3) across services; everything else is stable.
parameter_levels <- c("ozone", "pm2.5", "pm10", "co", "no2", "so2")


#' Build a factor, warning about values that would silently become NA
#'
#' @param x Character vector
#' @param levels Allowed levels
#' @param what Noun for the warning message, e.g. "parameter"
#' @param ordered Passed to [factor()]
#' @return A factor
#' @noRd
factor_with_warning <- function(x, levels, what, ordered = FALSE) {
  x <- as.character(x)
  unmatched <- unique(x[!is.na(x) & !(x %in% levels)])
  if (length(unmatched) > 0) {
    cli::cli_warn(c(
      "Unrecognised {what} value{?s}: {.val {unmatched}}",
      "i" = "These will become {.val NA}. Please report this at {.url https://github.com/briandconnelly/airnow/issues}" # nolint
    ))
  }
  factor(x, levels = levels, ordered = ordered)
}


#' Convert API pollutant names to the package's canonical factor
#' @param x Character vector such as `c("OZONE", "PM2.5")`
#' @return An unordered factor on [parameter_levels]
#' @noRd
to_parameter_factor <- function(x) {
  x <- tolower(as.character(x))
  x[!is.na(x) & x == "o3"] <- "ozone"
  factor_with_warning(x, parameter_levels, "parameter")
}


#' Convert AQI category names to a factor
#' @param x Character vector such as `c("Good", "Moderate")`
#' @param ordered Whether the factor is ordered (`TRUE` for the new
#'   functions; the legacy shims use `FALSE`)
#' @return A factor on `category_levels`
#' @noRd
to_category_factor <- function(x, ordered = TRUE) {
  factor_with_warning(x, category_levels, "AQI category", ordered = ordered)
}


#' Convert the API's "HH:MM" hour label to an integer hour
#'
#' The 2026 services label an hour by its end: `"18:00"` is the period
#' 17:00-17:59. This function keeps that label (returns 18); it does not
#' shift it. See the compatibility shims for the old start-labelled hour.
#'
#' @param x Character vector such as `c("18:00", "00:00")`
#' @return Integer vector; `NA` where the label is missing or malformed
#' @noRd
hour_label_to_integer <- function(x) {
  x <- as.character(x)
  well_formed <- !is.na(x) & grepl("^[0-9]{2}:[0-9]{2}$", x)
  malformed <- !is.na(x) & !well_formed
  if (any(malformed)) {
    cli::cli_warn("Unexpected {.field hourObserved} value{?s}: {.val {unique(x[malformed])}}; returning {.val NA}") # nolint
  }
  out <- rep(NA_integer_, length(x))
  out[well_formed] <- as.integer(substr(x[well_formed], 1, 2))
  out
}


#' Derive a UTC datetime from AirNow's local date, hour, and zone label
#'
#' Rule (spec section 4.3):
#' 1. Start from the area's standard-time `gmt_offset`.
#' 2. If the area observes DST and `tz_abbr` equals its daylight
#'    abbreviation, add one hour to the offset.
#' 3. If `tz_abbr` equals the standard abbreviation, keep the offset.
#' 4. Otherwise the result is `NA` and a warning names the abbreviation.
#'    Never guess from a "DT" suffix: AirNow's abbreviations are not
#'    standard (Anchorage is recorded as `AKT`/`ADT`).
#'
#' @param date `Date` vector (the API's `dateObserved`)
#' @param hour Integer vector (the API's end-of-period hour label)
#' @param tz_abbr Character vector (the API's `localTimeZone`)
#' @param reporting_area_code Character vector of area codes
#' @return `POSIXct` in UTC, `NA` where any input is missing or the zone
#'   cannot be matched
#' @noRd
derive_utc_datetime <- function(date, hour, tz_abbr, reporting_area_code) {
  areas <- areas_table()
  idx <- match(reporting_area_code, areas$reporting_area_code)

  offset <- areas$gmt_offset[idx]
  is_daylight <- areas$observes_dst[idx] & tz_abbr == areas$tz_daylight[idx]
  is_standard <- tz_abbr == areas$tz_standard[idx]
  is_daylight[is.na(is_daylight)] <- FALSE
  is_standard[is.na(is_standard)] <- FALSE

  unmatched <- !is.na(idx) & !is.na(tz_abbr) & !is_daylight & !is_standard
  if (any(unmatched)) {
    cli::cli_warn("Could not match time zone{?s} {.val {unique(tz_abbr[unmatched])}} to the reporting area metadata; {.field utc_datetime} will be {.val NA}") # nolint
  }

  offset <- offset + ifelse(is_daylight, 1L, 0L)
  known <- !is.na(idx) & !is.na(date) & !is.na(hour) & (is_daylight | is_standard)

  local_midnight <- as.POSIXct(date, tz = "UTC")
  out <- local_midnight + hour * 3600 - offset * 3600
  out[!known] <- NA
  attr(out, "tzone") <- "UTC"
  out
}
```

- [ ] **Step 4: Extend `clean_names()` in `R/utils.R`**

Replace the whole of `R/utils.R` with:

```r
#' Convert lowerCamelCase to snake_case
#'
#' Handles runs of capitals: `nowcastAQI` -> `nowcast_aqi`,
#' `dailyAQICategoryName` -> `daily_aqi_category_name`.
#'
#' @param x Character vector of names
#' @return Character vector
#' @noRd
camel_to_snake <- function(x) {
  x <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  x <- gsub("([A-Z]+)([A-Z][a-z])", "\\1_\\2", x)
  tolower(x)
}


clean_names <- function(x) {
  if (!is_named(x)) {
    cli::cli_abort("Object must have a {.field names} attribute")
  }

  # Explicit mappings win. Legacy (pre-2026) names first, then the names the
  # 2026 services use where the generic conversion would be wrong or ugly.
  name_mapping <- c(
    "DateObserved" = "date_observed",
    "HourObserved" = "hour_observed",
    "LocalTimeZone" = "local_time_zone",
    "ReportingArea" = "reporting_area",
    "StateCode" = "state_code",
    "Latitude" = "latitude",
    "Longitude" = "longitude",
    "ParameterName" = "parameter",
    "AQI" = "aqi",
    "Category.Number" = "category_number",
    "Category.Name" = "category_name",
    "DateIssue" = "date_issued",
    "DateForecast" = "date_forecast",
    "ActionDay" = "action_day",
    "Discussion" = "discussion",
    "UTC" = "datetime_observed",
    "Parameter" = "parameter",
    "Unit" = "unit",
    "Value" = "value",
    "RawConcentration" = "raw_concentration",
    "Category" = "category_number",
    "SiteName" = "site_name",
    "AgencyName" = "site_agency",
    "FullAQSCode" = "aqs_code",
    "IntlAQSCode" = "intl_aqs_code",
    "parameterName" = "parameter",
    "reportingAreaName" = "reporting_area",
    "nowcastAQI" = "aqi",
    "aqiCategoryName" = "category_name",
    "dailyAQI" = "aqi",
    "dailyAQICategoryName" = "category_name",
    "siteID" = "site_id"
  )

  nms <- names(x)
  mapped <- nms %in% names(name_mapping)
  nms[mapped] <- unname(name_mapping[nms[mapped]])
  nms[!mapped] <- camel_to_snake(nms[!mapped])
  names(x) <- nms
  x
}
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `Rscript -e 'devtools::test(filter = "normalize|utils")'`
Expected: `FAIL 0`.

- [ ] **Step 6: Run the whole suite**

Run: `Rscript -e 'devtools::test()'`
Expected: `FAIL 0`. (`get_airnow_conditions()` and friends still call `clean_names()`; their legacy names are all in the explicit mapping, so their output is unchanged.)

- [ ] **Step 7: Commit**

```bash
git add R/normalize.R R/utils.R tests/testthat/test-normalize.R \
  tests/testthat/test-utils.R
git commit -m "$(cat <<'EOF'
feat: add value-normalization helpers for the 2026 AirNow services

Parameter and AQI-category factors that warn on unknown values instead of
silently producing NA, an HH:MM hour parser, a UTC datetime derivation
from the reporting-area metadata, and generic lowerCamelCase-to-snake_case
name cleaning.

🤖 Generated with Claude Code
Claude-Session: https://claude.ai/code/session_0183jP8PzrHQjr51b8AWuRLk
EOF
)"
```

---

### Task 7: Foundation gate

No new code. Confirms the package still builds and checks cleanly before Plan 2 starts.

- [ ] **Step 1: Full check**

Run: `Rscript -e 'devtools::check(document = TRUE, error_on = "never")' 2>&1 | tail -30`
Expected: the summary ends with `0 errors ✔ | 0 warnings ✔ | N notes` where the only acceptable notes are about the checking environment (e.g. "unable to verify current time", or a future-dated package). A note like `no visible binding for global variable 'airnow_areas'` means some code used the bare dataset name instead of `areas_table()`; fix it.

- [ ] **Step 2: Lint**

Run:
```bash
Rscript -e 'if (!requireNamespace("lintr", quietly = TRUE)) install.packages("lintr", repos = "https://cloud.r-project.org"); lints <- lintr::lint_package(); print(lints); cat("lint count:", length(lints), "\n")'
```
Expected: `lint count: 0`. If lints appear only in files this plan did not touch (`compat-purrr.R`, `get_airnow_area.R`), report them and move on; fix anything in files this plan created or edited.

- [ ] **Step 3: Confirm git is clean and report**

Run: `git status --short && git log --oneline -8`
Expected: no uncommitted changes; the log shows the six commits from Tasks 1-6 on top of `c5ea778 Update NEWS`.

Report the check summary line and the lint count verbatim. Then hand off to `dev/superpowers/plans/2026-09-12-airnow-migration-2-retrieval.md`.
