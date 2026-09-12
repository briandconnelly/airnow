# airnow: redesign around the 2026 AirNow API web services

**Date:** 2026-09-09, revised 2026-09-12 after review
**Status:** Design approved. Phase 1 implementation plans written 2026-09-12:
`dev/superpowers/plans/2026-09-12-airnow-migration-1-foundation.md` and
`dev/superpowers/plans/2026-09-12-airnow-migration-2-retrieval.md`. Work is phased in
section 10; only phase 1 is on the deadline.
**Target release:** 0.2.0 (phase 1), 0.2.1 (phase 2)
**Hard deadline:** 2026-09-30 (retirement of six AirNow web services)

---

## 1. Context

AirNow retires six web services on **2026-09-30**. Four of those six endpoints are used
by this package, across two functions:

| Package function | Endpoint | Fate |
|---|---|---|
| `get_airnow_conditions()` | `/aq/observation/zipCode/current/`, `/aq/observation/latLong/current/` | Retiring |
| `get_airnow_forecast()` | `/aq/forecast/zipCode/`, `/aq/forecast/latLong/` | Retiring |
| `get_airnow_area()` | `/aq/data/` | Unaffected |

Six replacement services were released 2026-06-17. They are not drop-in replacements:
field names, parameter vocabularies, the current/historical split, and the accepted
location inputs all changed.

Announcement: <https://docs.airnowapi.org/docs/AirNowAPIUpdates2026June.pdf>

---

## 2. Verified findings

Everything in this section was confirmed against the live API on 2026-09-09 (and
2026-09-12 for the items marked so), not read from documentation. Where the documentation disagrees with the service, the service wins
and the discrepancy is noted. **The published documentation is wrong in three places that
would each have produced a shipped bug.**

### 2.1 Documentation errors

| Docs say | Reality | Evidence |
|---|---|---|
| `/aq/forecast/historical/` takes `apiKey` | Takes `api_key`. `apiKey` returns `401 {"WebServiceError":[{"Message":"Request not authenticated."}]}` | Both spellings probed |
| Observation fields are `AQICategoryName`, `LookupBehavior`, `ConsideredMonitors`, `LookupBoundary` | JSON returns `aqiCategoryName`, `lookupBehavior`, `consideredMonitors`, `lookupBoundary`. All endpoints are uniformly lowerCamelCase | JSON payloads inspected |
| `/aq/dailydata/` returns `concentration` / `concentrationUnits` | With `datatype=A` it returns `aqi`, `categoryNumber`, `categoryName` and omits the concentration fields. The field set varies by `datatype` | Probed with `datatype=A` |

### 2.2 Transport

- **HTTPS is required.** Every `http://` request returned
  `301 -> https://www.airnowapi.org:443/...`. The package currently uses
  `http://www.airnowapi.org/aq` (`R/api.R:17`), so the API key makes its first hop in
  plaintext today. Fix independent of this migration.
- Path casing and trailing slashes are **not** significant: `ziplatLong`, `ziplatlong`,
  and `ziplatLong/` all returned identical `200`s.
- `api_key` is the key parameter on all seven endpoints.

### 2.3 Semantics

- **Location -> area code resolution works for both input types.**
  `/aq/forecast/current/?zipCode=90210` returns `reportingAreaCode: "ca132"`;
  `/aq/forecast/current/?latitude=38.3191&longitude=-122.2998` returns
  `reportingAreaCode: "ca064"` **and** `stateCode: "CA"`. For zip codes this is the only
  route — the metadata file contains no zip codes. For coordinates there is also an
  offline route (nearest neighbour in `airnow_areas`), but the API route is exact and is
  what `resolve_area_code()` uses.
- **`hourObserved` shifted by one hour.** Parallel calls at the same instant
  (local time 18:22) returned old `HourObserved: 17` and new `hourObserved: "18:00"`.
  Both describe the period 17:00-17:59; the old service labels by start, the new by end.
  **Any shim must subtract one hour.**
- **AQI values are not identical between old and new services.** Two samples for zip
  90210: one matched (`O3 34` / `OZONE 34`), one did not (`O3 32` / `OZONE 34`). The
  lookup methodologies differ. The compatibility layer preserves *shape*, not *values*.
- **`localTimeZone` is now correct.** The old service returned `PST` in September; the
  new service returns `PDT`.
- **Row counts increase.** Old `/observation/zipCode/current/` returned 1 record for
  90210; new `/ziplatLong` returns 3 (PM2.5, OZONE, PM10). Old
  `/forecast/zipCode/` returned 5 rows; new `/forecast/current/` returns 10.
- **Old `date` semantics.** `/aq/forecast/zipCode/?date=2026-01-13` returns ten rows:
  five parameters valid on the 13th (issued the 12th) *and* five issued on the 13th
  (valid the 14th). The new historical service filters on `dateValid` and returns all
  forecast lead times unless `forecastRange` is given.
- **`distance` is ignored by the new services (verified 2026-09-12).** `/ziplatLong` for
  zip 90210 returned byte-identical payloads with and without `distance=25`. For a point
  in central Nevada (39.5, -116.9), `distance=300` still returned
  `"No observations were found for all monitors within 50 miles"`; `/forecast/current/`
  likewise returned `"There is no reporting area at your searched location"` with and
  without `distance`. The old `/observation/zipCode/current/` still honours `distance`.
  The search radius is now fixed per reporting area (`lookup_boundary` in the metadata).
  Probes: `new/observation_current_ziplatLong__distance25_ignored.json`,
  `new/*__nevada_distance300_ignored.json`.
- **`/aq/forecast/historical/` serves forecasts valid today (verified 2026-09-12).**
  `reportingAreaCode=ca132&startDate=2026-09-12&endDate=2026-09-13` at 08:39 PDT returned
  the same five rows (`dateIssue: 2026-09-11`, `dateValid: 2026-09-12`) that
  `/forecast/current/` returned at the same moment. **Whether it serves forecasts valid
  in the future is unverified**: no forecast valid on the 13th had been issued yet, so
  the empty result for that day is uninformative. Re-probe in the afternoon, after the
  next issuance. Probes: `new/forecast_historical__today_ca132.json`,
  `new/forecast_current__zip_2026-09-12.json`.
- **"No data" is a `200` with a `WebServiceError` body**, not an empty array, on both
  `/ziplatLong` and `/forecast/current/` (the Nevada probes above). This is the
  same envelope as authentication failures (`401`), so error detection has to parse the
  body regardless of status. See section 6.

### 2.4 Parameter vocabulary

| Service | Values observed |
|---|---|
| Old (both) | `O3`, `PM2.5`, `PM10`, `CO`, `NO2` |
| `/forecast/current/`, `/forecast/historical/`, `/ziplatLong`, `/racode`, `/observation/historical/state/` | `OZONE`, `PM2.5`, `PM10`, `CO`, `NO2` |
| `/aq/dailydata/` | `Ozone`, `PM25` |

Only ozone and PM2.5 vary. Everything else is stable across services.

`so2` was **not observed** in any probe response. It is documented as a valid value for
the `parameter` input of `/aq/forecast/historical/`, which is the basis for including it
as a factor level in section 4.3 — documentation, not observation.

### 2.5 AQI category numbering and range

The full numbering is **verified** against historical observations from severe smoke
events (Bay Area Sept 2020, LA Jan 2025, Portland Sept 2020) via `/aq/dailydata/`:

| Number | Name |
|---|---|
| 1 | Good |
| 2 | Moderate |
| 3 | Unhealthy for Sensitive Groups |
| 4 | Unhealthy |
| 5 | Very Unhealthy |
| 6 | Hazardous |

This matches the ordering in `R/aqi.R` exactly. Category `7 = Unavailable` is documented
but was not observed; it is a sentinel rather than a reading.

**AQI values exceed 500 in real data.** The Portland query returned a maximum daily AQI of
**874** (Vancouver-NE 84th Ave, 2020-09-13), with 13 records above 500 in a single
bounding box and date range. The package's `check_aqi()` rejects anything above 500, so
`aqi_descriptor(874)` and `aqi_color(874)` both abort:

```
aqi_descriptor(500) -> Hazardous
aqi_descriptor(501) -> ERROR: `aqi` must be an integer between 0 and 500, inclusive
```

Piping real package output into the package's own helpers therefore errors on smoke-event
data. This is a pre-existing bug, unrelated to the migration, but it is in scope now
because the new daily-observation service makes such values much easier to retrieve.

### 2.6 Reporting area metadata

`https://files.airnowtech.org/airnow/today/reportingarea_metadata.dat` is **public**
(HTTP 200, no authentication), 157 KB, pipe-delimited, 14 fields:

```
Anchorage|AK|US|61.2167|-149.9|-9|Yes|AKT|ADT|ak001|State of Alaska DEC|Closest Reading By Pollutant|All AirNow Monitors|50 miles
```

name, state, country, latitude, longitude, GMT offset, observes DST, standard tz,
daylight tz, **area code**, agency, lookup behavior, considered monitors, lookup boundary.

- 1,037 rows; 1,036 distinct (Monterrey, MX / `mx002` appears twice, verbatim).
- **26 area names collide across states (after removing the duplicate Monterrey
  row)** (Aberdeen, Albany, Ashland, Charleston, Columbia, Columbus, ...).
- Area codes are unique apart from the duplicated row.
- Name-based joins were spot-checked against live responses and matched
  (`NW Coastal LA` -> `ca132`, `Napa` -> `ca064`, `Northeast Maryland` -> `md008`,
  `Metro Baltimore` -> `md001`).

`/ziplatLong` returns neither `reportingAreaCode` nor `stateCode`, so a name-only join
cannot disambiguate the 26 collisions.

---

## 3. Design decisions

| Decision | Choice |
|---|---|
| Overall approach | Redesign around the new services; keep old functions as deprecated shims |
| Area lookup | Bundled `airnow_areas` dataset; API fallback for zip codes |
| Compatibility depth | Full — old signatures *and* old column names |
| Naming | `get_airnow_*()` prefix retained, new nouns for new functions |
| Ambiguous name joins | Lazy code resolution — one extra request only for colliding names, cached |
| Credentials | Standardize on `key`: `AIRNOW_API_KEY`, `get_airnow_key()` / `set_airnow_key()` |

---

## 4. Public surface

### 4.1 Retrieval

| Function | Endpoint | Location input |
|---|---|---|
| `get_airnow_forecasts()` | `/aq/forecast/current/` | `zip`, `latitude`+`longitude`, or `area` |
| `get_airnow_forecast_history()` | `/aq/forecast/historical/` | `area`, `start_date`, `end_date`, opt. `range`, `parameter` |
| `get_airnow_observations()` | `/ziplatLong` or `/racode` | `zip`, `latitude`+`longitude`, or `area` |
| `get_airnow_observation_history()` | `/aq/observation/historical/state/` | `state`, `start_date`, `end_date` |
| `get_airnow_monitors()` | `/aq/data/` | `box` (hourly) |
| `get_airnow_monitors_daily()` | `/aq/dailydata/` | `box`, `start_date`, `end_date` (daily) |
| `get_airnow_reporting_area()` | `/aq/forecast/current/` | `zip`, or `latitude`+`longitude` |

`get_airnow_reporting_area()` returns one row: `reporting_area_code`, `reporting_area`,
`state_code`, `latitude`, `longitude`. It was `get_airnow_area_code()` in the first draft;
renamed because section 4.2's objection to `get_airnow_area_observations()` applied to
it too (section 8, question 1).

**Phase 1 (0.2.0, on the deadline):** `get_airnow_forecasts()`,
`get_airnow_forecast_history()`, `get_airnow_observations()`,
`get_airnow_reporting_area()`, `get_airnow_monitors()`, and `airnow_areas`.
**Phase 2 (0.2.1):** `get_airnow_observation_history()` and
`get_airnow_monitors_daily()`. Nothing existing depends on the phase 2 services, so they
have no deadline. `get_airnow_forecast_history()` is in phase 1 only because the
`get_airnow_forecast(date = )` shim needs the same request code (section 5.2); the
exported wrapper is trivial once that exists.

Plus the exported dataset `airnow_areas` (1,036 rows).

Credentials: `get_airnow_key()`, `set_airnow_key()`.

Unchanged: `aqi_color()`, `aqi_descriptor()`.

### 4.2 Two deliberate choices

**`get_airnow_observations()` fronts both observation services.** A separate
`get_airnow_area_observations()` would sit confusingly close to the deprecated
`get_airnow_area()` for the whole deprecation window. The two services return different
columns; the function always returns the **union** so the shape is stable:

- `site_id` / `site_name` are `NA` for `area` queries (the `/racode` service omits them).
- `reporting_area_code` / `reporting_area_agency` come from `/racode` directly, and from
  the `airnow_areas` join for zip and lat/long queries.
- The methodology difference (closest-reading-by-pollutant vs. agency-maximum) is
  documented and surfaced in `lookup_behavior`.
- A **`source` factor column** (`ziplatlong` / `racode`) records which service produced
  each row. Without it, an `NA` in `site_id` is ambiguous between "this was an area query"
  and "this was a point query and the service returned no site", and users filtering on
  `is.na(site_id)` would misattribute rows.

**`get_airnow_monitors_daily()` accepts a `box`**, matching `get_airnow_monitors()`, even
though `/aq/dailydata/` wants four separate `maxlat`/`minlat`/`maxlon`/`minlon`
parameters. Symmetry between the two bounding-box functions is worth the translation.

### 4.3 Return contract

Every retrieval function returns a tibble. The area-based services return one row per
parameter, or per parameter per date for forecast and historical services. The monitor
functions return one row per site, parameter, and hour (`get_airnow_monitors()`) or day
(`get_airnow_monitors_daily()`). With `clean_names = TRUE` (default) names are
snake_case — a clean mechanical transform now that the live API is uniformly
lowerCamelCase.

Normalizations applied on top of the API response:

- **`parameter`** — factor with stable levels `ozone`, `pm2.5`, `pm10`, `co`, `no2`,
  `so2`, absorbing the `OZONE` / `Ozone` / `O3` variation. This is the one place the
  package overrides the API, because the variation is incidental.
- **`category_name`** — factor on the existing seven levels. Note the current code calls
  `factor()` **without `ordered = TRUE`** (`R/get_airnow_conditions.R:67`), so today's
  contract is an *unordered* factor. AQI categories have a natural order and `ordered = TRUE`
  would be an improvement, but it changes comparison and sorting behaviour for downstream
  code — so it is a deliberate decision, not an incidental one. **Decided (section 8,
  question 3): `ordered = TRUE` in the new functions; the shims keep today's unordered
  factor.**
  **`category_number`** — from the API where provided, from the name where not.
- **`hour_observed`** — integer hour, **keeping the API's end-of-period label**:
  `"18:00"` becomes `18L`, meaning the period 17:00-17:59. The new functions do *not*
  subtract an hour and do not touch `date_observed`; only the compatibility shims do
  (section 5.1). This must be stated in `?get_airnow_observations`, because a user
  comparing the shim and the new function for the same instant will see `17` and `18`.
  `"00:00"` becomes `0L` with whatever date the API supplied.
- **Dates** — `Date`.
- **Timezone caveat.** `hour_observed` and `date_observed` are **local to each reporting
  area**, and `local_time_zone` is an abbreviation like `"PDT"` that R cannot parse as a
  timezone. A multi-area result (an `area` query, or state history) therefore mixes
  incomparable clocks, and joining against `get_airnow_monitors()` — whose `UTC` column is
  parsed with `tz = "UTC"` at `R/get_airnow_area.R:113` — will silently misalign by each
  area's offset. `airnow_areas` carries GMT offset, a DST flag, and both timezone
  abbreviations, which is enough to derive a `utc_datetime` (POSIXct) after correcting
  one source limitation: the metadata rounds fractional offsets to whole hours. The
  build script restores the known `AFT`, `IST`, `MMT`, and `NPT` half- and quarter-hour
  offsets. The metadata's abbreviations are not standard: Anchorage carries `AKT|ADT`
  rather than `AKST|AKDT`, so an abbreviation that the API returns is not guaranteed to
  match either metadata column. Rule:

  1. `offset <- gmt_offset`.
  2. If `observes_dst == "Yes"` and `local_time_zone` equals the area's daylight
     abbreviation, `offset <- offset + 1`.
  3. If `local_time_zone` equals the standard abbreviation, leave it.
  4. If it matches neither, `utc_datetime` is `NA` for that row and a `cli_warn()`
     names the abbreviation. Never guess from the `DT` suffix.

  Required fixtures: a DST area in summer (`PDT`), a non-DST area (Phoenix; metadata
  `observes_dst == "No"`), and a mismatch row that must yield `NA` with a warning.
  Deriving `utc_datetime` is phase 1; the locality caveat is documented either way.
  `utc_datetime` denotes the *end* of the observation hour, matching the API's
  label; `get_airnow_monitors()$datetime_observed` denotes the *start*. Whether
  0.2.1 should shift `utc_datetime` to period start for consistency is an open
  decision; 0.2.0 documents the one-hour difference.
- **`state_code`, `latitude`, `longitude`, `reporting_area_code`** — added by the
  `airnow_areas` join to services that no longer return them.

**Out-of-vocabulary factor values must warn, not vanish.** `factor(x, levels = ...)`
silently returns `NA` for any unrecognised value — verified:

```r
factor(c("Good", "Unhealthy", "Beyond Index"), levels = category_levels)
#> [1] Good      Unhealthy <NA>
```

The package already has this exposure at `R/get_airnow_conditions.R:69` and
`R/get_airnow_forecast.R:62`, and the new `parameter` factor adds a second instance. If
AirNow introduces a pollutant or renames a category, the column silently becomes `NA` and
downstream `filter()` calls quietly drop rows. Both conversions must detect unmatched
values first and emit a `cli_warn()` naming them, then coerce. This is cheap and turns a
silent data-loss bug into a visible one.

---

## 5. Compatibility layer

Five deprecated functions, warning via `lifecycle::deprecate_warn()`:
`get_airnow_conditions()`, `get_airnow_forecast()`, `get_airnow_area()`,
`get_airnow_token()`, `set_airnow_token()`.

The existing tests already specify the target contract for both `clean_names` settings
(`tests/testthat/test-get_airnow_conditions.R:44`), so the goal is that those files pass
unchanged.

### 5.1 Observation column translation

| Old column | Source | Transform |
|---|---|---|
| `DateObserved` | `dateObserved` | direct, **except** when the hour wraps — see below |
| `HourObserved` | `hourObserved` | **`"18:00"` -> `17`** (end -> start of period) |
| `LocalTimeZone` | `localTimeZone` | direct (value now correct) |
| `ReportingArea` | `reportingAreaName` | direct |
| `StateCode`, `Latitude`, `Longitude` | `airnow_areas` | join with lazy code resolution |
| `ParameterName` | `parameterName` | `OZONE` -> `O3`; others pass through |
| `AQI` | `nowcastAQI` | direct |
| `Category.Name` | `aqiCategoryName` | direct |
| `Category.Number` | derived | name -> number |

### 5.2 Forecast column translation

`test-get_airnow_forecast.R:70-84` asserts a twelve-column contract. Mapping, all sources
verified present in `/aq/forecast/current/` responses:

| Old column | Source | Transform |
|---|---|---|
| `DateIssue` | `dateIssue` | direct |
| `DateForecast` | `dateValid` | rename |
| `ReportingArea` | `reportingArea` | direct |
| `StateCode` | `stateCode` | direct (returned; no join needed) |
| `Latitude`, `Longitude` | `airnow_areas` | join **on `reportingAreaCode`** |
| `ParameterName` | `parameterName` | `OZONE` -> `O3` |
| `AQI` | `aqi` | direct |
| `ActionDay` | `actionDay` | direct |
| `Discussion` | `discussion` | direct (may be `""`) |
| `Category.Number` | `categoryNumber` | direct |
| `Category.Name` | `categoryName` | direct |

The forecast shim is **easier** than the observation shim: `/aq/forecast/current/` returns
`reportingAreaCode` and `stateCode` directly, so its join is on the code — exact, with none
of the 27-name ambiguity that affects `/ziplatLong`.

**Midnight wraparound — UNVERIFIED, must be confirmed before implementation.** The hour
shift is not a simple subtraction: `hourObserved = "00:00"` describes 23:00-23:59, and
handling only the interior case would emit `hour_observed = -1`.

What is *not* established is which date accompanies that hour. The section 2.3 evidence was
gathered at 18:22 local; **no probe has ever observed a `"00:00"` response.** If
`dateObserved` is the new calendar day, the shim must also decrement the date; if AirNow
labels the date by observation day while labelling the hour by period end, decrementing
would double-shift it. Assuming either way and encoding the assumption in a hand-authored
fixture would produce a bug that ships "tested" against itself.

**Verification required:** capture a real response between 00:00 and 00:59 local in any
reporting area, from both the old and new services, before 2026-09-30. A scheduled probe
is the only practical way — the window is one hour per timezone per day. Additionally, the
wrap logic must be NA-safe: an `NA` or unexpectedly formatted `hourObserved` must not be
compared or indexed unchecked.

Site and lookup-behavior columns are dropped.

**`distance` is validated, then warned, then ignored — in that order.** The new services
ignore the parameter (section 2.3, verified), so there is nothing to pass through. The
existing tests require invalid values to *error*: `expect_error(..., distance = NA_real_)`,
`-30`, and `1:5` (`test-get_airnow_conditions.R:22-24`, `test-get_airnow_forecast.R:22-24`).
So the shims must keep calling `check_distance()` before emitting the deprecation warning.
"Warns and is ignored" alone would break six assertions and quietly abandon the
pass-unchanged goal. A non-`NULL` `distance` gets its own `cli_warn()` saying the new
services use a fixed per-area radius.

**The `date` path costs two requests and is verified only for today.**
`/aq/forecast/historical/` accepts only a `reportingAreaCode` (section 4.1), so
`get_airnow_forecast(zip = , date = X)` must first resolve the area code through
`resolve_area_code()` (one request, memoised per location) and then call the historical
service with `startDate = endDate = X` (a second request). The historical service returns
today's forecasts (section 2.3), so `date = Sys.Date()` keeps working. Whether it returns
forecasts valid *tomorrow* is unverified; the shim passes such dates through unchanged and
returns whatever the service does, which may be zero rows. Do not add a special case for
future dates until the afternoon re-probe in section 2.3 settles it.

### 5.3 Documented divergences

The deprecation notice must state these, because they cannot be papered over:

1. **Row counts and included parameters may differ**, because the new service reports one
   row per parameter. Observed: old returned 1 row for zip 90210 where new returned 3. That
   is a single location's sample and should not be stated as "old always returned one".
2. **AQI values may differ** from the old service (different lookup methodology).
3. **`LocalTimeZone` is now correct**, where the old service was wrong.
4. **`get_airnow_forecast(date = X)` narrows** to forecasts *valid* on `X` at
   `range = 1`. The old service also returned forecasts *issued* on `X` (valid `X+1`);
   the new service is organized by validity date and reproducing both halves would bend
   it out of shape.
5. **`distance` no longer has any effect.** The new services search a fixed radius per
   reporting area (section 2.3). The argument is still validated so existing error tests
   pass, then warned about and ignored.

---

## 6. Internals

- **`req_airnow()`** — base `https://www.airnowapi.org/aq`, unchanged throttle, `api_key`
  as the key parameter.
- **Error handling** (currently absent) — AirNow returns
  `{"WebServiceError":[{"Message":"..."}]}` under `200` for "no data" and under `401` for
  bad credentials (section 2.3). Two pieces:
  1. `req_airnow()` sets `httr2::req_error(body = airnow_error_body)`, where the
     helper extracts `Message`. Otherwise a `401` surfaces as httr2's generic
     "HTTP 401 Unauthorized" and the API's explanation is lost — exactly what the
     `apiKey` probe showed.
  2. After a successful response, check for the `WebServiceError` key before building a
     tibble. **"No data" must not abort.** The old services returned an empty array;
     the shims must keep returning a zero-row tibble with the contracted columns, and the
     new functions do the same. Any other message aborts via `cli_abort()` with the API
     text.
  3. The retirement contingency in section 10 hooks in here: once the message the retired
     endpoints emit is known, match it and abort with the replacement function's name.
- **`airnow_areas`** — package data built by a `data-raw/` script that downloads the
  metadata file, drops the duplicated Monterrey row, and names the 14 columns. Staleness
  between releases is a documented caveat. Packaging requirements, all verified against the
  actual file:
  - **CRLF line terminators.** `file(1)` reports "ASCII text, with CRLF line terminators".
    The parser must strip `\r` or the last field of every row acquires a trailing carriage
    return — silently corrupting `lookup_boundary` and any join on it.
  - **Encoding.** The file is valid UTF-8 and contains exactly two non-ASCII bytes, in one
    row (Guanajuato). Convert explicitly to UTF-8 in `data-raw/` and add a regression test
    asserting that row round-trips, or it will render as mojibake on some platforms.
  - **Documentation.** Exported data needs a roxygen `@source` block with the URL and
    retrieval date, plus a note on EPA/AirNow provenance for the redistribution story.
    Undocumented exported data is an `R CMD check` warning on submission.
- **`resolve_area_code()`** — one internal entry point, accepting either a zip or a
  coordinate pair. Offline via `airnow_areas` when the reporting area name is unambiguous.
  For a colliding name with **coordinate** input, resolve offline too: pick the same-named
  row nearest to the query point. The 26 collisions are all in different states, hundreds
  of miles apart, so nearest-neighbour among two or three candidates is unambiguous and
  costs no request. Only a colliding name with **zip** input needs the API: one call to
  `/aq/forecast/current/`, which returns `reportingAreaCode` for both input types
  (verified, section 2.3). Memoised in a session-level environment keyed by location.
- **Rate-limit budget.** Disambiguation calls come out of the same 500/hour allowance as
  everything else, so a loop over many colliding-name locations can double its request
  count. The session memo bounds this to one call per distinct location; the throttle in
  `req_airnow()` still applies. Document the cost in the *new* retrieval functions' help pages, not only in the deprecated
  `?get_airnow_conditions`.
- **Credentials** — standardize on "key" throughout, matching the API's own vocabulary.
  `get_airnow_key()` / `set_airnow_key()` read and write `AIRNOW_API_KEY`; the `api_key`
  argument name on every retrieval function already agrees. `get_airnow_token()` and
  `set_airnow_token()` become deprecated shims alongside the others.
  No `AIRNOW_API_TOKEN` fallback — one name only.

  *Migration note:* the maintainer's shell currently sets `AIRNOW_API_TOKEN`, which is why
  the network tests have been skipping (section 7). That variable needs renaming to
  `AIRNOW_API_KEY` locally, or the same silent-skip persists after this work lands.

---

## 7. Testing

Current network tests skip when `AIRNOW_API_KEY` is unset
(`tests/testthat/test-get_airnow_conditions.R:38`).

**Scope of the skip, corrected.** Pull-request workflows deliberately do not receive
`AIRNOW_API_KEY`: they execute code from the proposed change, so exposing a live key there
would let that code read or transmit it. `.github/workflows/live-smoke.yaml` supplies the
key only after a push to the protected default branch (or a manual dispatch). Local runs
also skip unless `AIRNOW_API_KEY` is set. Make the skip emit a visible message either way,
so "skipped" is never mistaken for "passed".

Three layers:

0. **Scalar-input decision.** `check_zip()` / `check_location()` are scalar-only today
   (`R/argument_checks.R`), and the tests enforce it. The redesign **keeps** that
   limitation deliberately rather than by omission: one location per call, one request per
   call. Vectorized lookup is out of scope for 0.2.0 and should be recorded as such so it
   is a decision rather than an oversight.
1. **Argument validation** — no network, already adequate, extend to new functions.
2. **Recorded fixtures** — add `httptest2` to `Suggests`.

   **A redactor is mandatory, not optional.** Every request carries `api_key` as a URL
   query parameter, and httptest2 identifies recorded requests by hashing the full URL
   including the query string. Without `set_redactor()` normalising `api_key` to a fixed
   placeholder, two things go wrong: fixtures recorded under one key never match requests
   made under another, so CI and other contributors silently miss the fixture and fall
   through to a live network call; and the raw key can be persisted into fixture files,
   which would then be committed to git and shipped inside the CRAN tarball. Belt and
   braces: every mocked test also sets a placeholder key with
   `withr::local_envvar(AIRNOW_API_KEY = "test-key")`, so playback builds the same URL on
   every machine regardless of the developer's real key, and the redactor only has to be
   right at record time. Add a CI check that no file under the fixture directory contains
   a key-shaped string — **case-insensitive**, since AirNow keys are lowercase hex
   (`grep -riE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'`).

   Record all seven endpoints so
   column names, types, and factor levels are checked on CRAN and in CI. Includes the two
   shim contracts exactly as written today. Fixtures must cover, specifically:
   - **`hourObserved = "00:00"`** — the midnight wraparound in section 5.1. This is a
     hand-authored fixture; it will not appear in a recording unless one happens to be
     made in that hour.
   - **A join miss** — a `reportingAreaName` absent from `airnow_areas` (areas get renamed
     and retired; the historical-observations docs warn about exactly this). The expected
     behaviour is a warning plus `NA` geography, not an error and not a silent drop.
   - **A colliding name** — one of the 27, to exercise lazy code resolution.
3. **Live smoke test** — `skip_on_cran()` plus the existing key gate, so it never runs in
   a CRAN check. CRAN forbids network access in tests, examples, and vignettes, so this
   layer exists only for local and CI runs; roxygen examples stay wrapped in `\dontrun{}`
   as they are today. Run deliberately. Re-checks the assumptions
   verified in section 2: `api_key` naming, HTTPS redirect, the one-hour offset, that
   area names still join, that `distance` is still ignored, and that the category
   numbering in section 2.5 still holds (category `7 = Unavailable` is the one value
   never observed; if it ever appears as a reading, this test is where it shows up).
   These are the facts most likely to drift, and a recorded fixture cannot detect drift by
   construction.

   **Run it on a schedule, not on memory.** A test that runs only when the maintainer
   remembers it does not run. Add a weekly cron GitHub Actions workflow invoking just this
   layer, so post-migration drift is actually detected (phase 2, section 10; until then
   the layer runs on every CI push, which is enough for the release window). This matters most *after*
   2026-09-30, when the old services are gone and there is nothing left to compare against.

---

## 8. Open questions

1. **Name for the area lookup function — decided 2026-09-12: `get_airnow_reporting_area()`.**
   Section 4.2 rejects `get_airnow_area_observations()` as too close to the deprecated
   `get_airnow_area()`; the same objection applied to the draft name
   `get_airnow_area_code()`. `get_airnow_reporting_area()` keeps the `get_airnow_*`
   scheme and reads as "the reporting area for this location", which is what it returns
   (code, name, state, coordinates). Section 4.1 updated.
2. **Ship HTTPS as a 0.1.2 hotfix? — decided 2026-09-12: no, one submission.** The first
   draft inferred an in-flight submission from the untracked `CRAN-SUBMISSION` file. That
   inference was wrong: CRAN published 0.1.1 on 2026-03-01 and the file is a six-month-old
   leftover (its SHA is the current `main`). The binding constraint is the opposite one —
   CRAN's policy asks for updates no more often than every one to two months, so a 0.1.2
   followed three weeks later by 0.2.0 risks the second submission being held. The HTTPS
   fix ships inside 0.2.0. It is still the first commit on the branch (section 10).
3. **`ordered = TRUE` on `category_name`? — decided 2026-09-12: yes in the new functions,
   no in the shims.** The new functions have no existing contract to break, and an ordered
   factor is what an AQI category is. The shims reproduce today's unordered factor, so
   code written against `get_airnow_conditions()` sees no change.
4. **Old-service comparison window.** The retiring endpoints stay up until 2026-09-30,
   which is the only period in which shim output can be diffed against the real thing.
   Worth capturing paired fixtures before the deadline.

## 9. AQI helper fix (added scope)

`check_aqi()`, `aqi_color()`, and `aqi_descriptor()` must accept values above 500
(section 2.5). The AQI scale is open-ended above Hazardous in practice, so the fix is to
clamp the lookup at the top breakpoint rather than raise the ceiling to another arbitrary
number. Specified behaviour:

| Input | `aqi_color()` / `aqi_descriptor()` |
|---|---|
| `0`-`500` | unchanged |
| `> 500` | Hazardous / `#7E0023` (clamped, no error) |
| `NA` | `NA`, **silently** |
| `-1` (forecast sentinel) | `NA` with a warning naming the sentinel |
| other negative | `NA` with a warning |
| non-integerish, `NULL`, zero-length | error, as today |

`NA` passes through without a warning because it is an ordinary value in a column these
helpers are meant to be mapped over — a join miss (section 7) or a missing reading
produces one, and warning on each would make the helpers unusable on real output. Only
negative values warn, because they are never legitimate readings. The `-1` sentinel is
issued when an agency gives a categorical rather than numerical forecast; it is documented
but was not observed in any probe. Note that today `check_aqi()` does not reject `NA`
deliberately: `any(NA < 0)` is `NA` and `if (NA)` errors, so the current behaviour is an
accident that the test happens to lock in. The `@param aqi` roxygen ("between 0 and 500,
inclusive") is updated to match the table.

**This changes existing tests.** `test-aqi.R:2-3` currently assert
`expect_error(aqi_color(-1))` and `expect_error(aqi_color(501))`, and `test-aqi.R:5`
asserts `expect_error(aqi_color(NA_integer_))`. All three must be rewritten. Unlike the
compatibility shims, this section deliberately changes the contract — so it must not be
described as "tests pass unchanged".

## 10. Sequencing and contingency

**18 days remain** as of this revision (2026-09-12), and the full scope is seven new
functions, a compatibility layer, a bundled dataset, a fixture-framework migration, an
AQI fix, and a scheduled workflow — with a CRAN review in the middle, which alone can
take a week. CRAN has no obligation to expedite. So the work is split, and only phase 1
is on the deadline.

**Phase 1 — 0.2.0, submit to CRAN by 2026-09-20.** Everything a current user needs to
keep working:

1. HTTPS base URL and the `test-api.R:10` assertion (first commit).
2. Error handling in `req_airnow()` (section 6).
3. `airnow_areas` and its `data-raw/` script.
4. `resolve_area_code()` and `get_airnow_reporting_area()`.
5. `get_airnow_forecasts()`, `get_airnow_forecast_history()`, `get_airnow_observations()`.
6. `get_airnow_monitors()` (rename only) and the five deprecated shims.
7. AQI helper fix (section 9).
8. httptest2 fixtures for the phase 1 endpoints, including the hand-authored midnight,
   join-miss, and colliding-name cases.

**Phase 2 — 0.2.1, no deadline.** `get_airnow_observation_history()`,
`get_airnow_monitors_daily()`, their fixtures, and the weekly drift workflow. Nothing in
the released package depends on these services. Deferring them is a decision, recorded
here, not an oversight; if phase 1 lands early they can be pulled forward.

**One CRAN submission, not two.** See section 8, question 2. Before submitting, delete
the stale `CRAN-SUBMISSION` file and commit the `.Rbuildignore` line that excludes it
(both currently sit uncommitted in the working tree).

**Do first, because the window closes permanently on 2026-09-30:**

1. **Capture paired old/new fixtures for every retiring endpoint.** After the deadline the
   old services are gone and shim output can never again be diffed against the real thing.
   This is the single most time-critical action in the spec and it does not depend on any
   design decision.
2. **Capture a post-midnight sample** (section 5.1) — the one-hour-per-timezone window
   means this needs scheduling, not opportunism.
3. **Capture a colliding-name sample** for the lazy-resolution path.

**The HTTPS fix is the first commit, not a separate release.** The base URL change is one
line, and it stops the API key crossing the network in plaintext on every call. The
exposure has existed since 0.1.0; folding it into 0.2.0 adds at most two weeks to a bug
that is already six months old, whereas a separate 0.1.2 could delay 0.2.0 past the
retirement date (section 8, question 2).

**If 0.2.0 misses the deadline**, `get_airnow_conditions()` and `get_airnow_forecast()`
start failing with raw API errors. Pre-stage a graceful path: detect the retirement
response and `cli_abort()` with a message naming the retirement date and the replacement
function. Note also that CI's live tests begin failing at retirement whether or not 0.2.0
has shipped.

## 11. Environment notes for whoever picks this up

Facts about this machine and toolchain that cost time to discover and are not
recoverable from the code:

- **Probe payloads are preserved at `dev/superpowers/probes/`** (gitignored, same as this
  spec). Includes paired old/new captures taken at the same instant — the evidence for the
  one-hour offset — plus the `401` proving `apiKey` is wrong. The `old/` half **cannot be
  re-captured after 2026-09-30**.
- **There is a second, stale airnow checkout** at `/Users/bdc/Documents/Projects/airnow`
  (v0.1.0.9000, last commit 2022). A review agent pointed at "the airnow repo" found that
  one instead of this one and reported the spec missing. Pin absolute paths.
- **`GH_TOKEN` is set to a `ghs_` App installation token** for `briandconnelly-agent[bot]`.
  Copilot CLI prefers it over the real login and fails with a server-to-server authz error;
  `env -u GH_TOKEN copilot ...` works.
- **`AIRNOW_API_TOKEN` is the shell variable present locally**, but the package reads
  `AIRNOW_API_KEY` (section 6). Until that is renamed, local network tests skip silently.
- **`~/Downloads/airnow-api-docs/*.html`** are the saved API docs — they embed a live API
  key in every page and should be scrubbed.
- **This spec and the probes are machine-local, and must stop being so.** `docs` is in
  `.gitignore`, so nothing here is backed up, and the `old/` probes are irreplaceable after
  2026-09-30. Checked 2026-09-12: no file under `dev/superpowers/` contains a credential
  (the only key-shaped match is a session UUID inside a path in `probe.sh`). Commit the
  directory. Git cannot re-include a subdirectory of an ignored directory, so the rule has
  to change from `docs` to:

  ```
  docs/*
  !dev/superpowers/
  ```

  `^docs$` in `.Rbuildignore` already keeps it out of the tarball. Do this before any
  other phase 1 work.

## 12. Out of scope
- The KML contour services, which the package has never wrapped.
- Any change to `get_airnow_monitors()` beyond the rename and the HTTPS base URL.
