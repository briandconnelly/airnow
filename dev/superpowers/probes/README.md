# Probe payloads captured 2026-09-09 and 2026-09-12

Evidence behind section 2 of the migration design spec. **`old/` cannot be
re-captured after 2026-09-30** — those endpoints are retired that day. `probe.sh`
reads the key from `$AIRNOW_API_TOKEN`; no payload here contains a credential.
It writes to `new/` by default; set `$AIRNOW_PROBE_OUT` to capture elsewhere.

## Paired old/new — same zip (90210), same instant
Captured with parallel requests, which is how the one-hour label offset was found.

| Old | New |
|---|---|
| `old/observation_zipCode_current__paired.json` (`HourObserved: 17`) | `new/observation_current_ziplatLong__paired.json` (`hourObserved: "18:00"`) |

## Still missing — see spec section 5.1
No response with `hourObserved = "00:00"` has ever been captured. The midnight
date-wrap rule is unverified without one, and the capture window for the paired
old-service half closes 2026-09-30.

## Notable payloads
- `new/forecast_historical__401_apiKey.json` — proves the documented `apiKey`
  parameter returns 401; `api_key` is correct on all seven endpoints.
- `new/dailydata__pdx2020_aqi_over_500.json` — Portland, Sept 2020. Max AQI 874,
  13 records above 500. `aqi_color()`/`aqi_descriptor()` error on these today.
- `new/dailydata__datatype_A.json` — returns `aqi`/`categoryNumber`/`categoryName`,
  not the `concentration` fields the docs' output table shows.
- `reportingarea_metadata.dat` — 1037 rows, CRLF, one non-ASCII row (Guanajuato).

## Added 2026-09-12 (review follow-up)
- `new/observation_current_ziplatLong__distance25_ignored.json` — byte-identical to the
  no-`distance` response for zip 90210. `distance` is ignored by the new services.
- `new/observation_current_ziplatLong__nevada_distance300_ignored.json` and
  `new/forecast_current__nevada_distance300_ignored.json` — (39.5, -116.9) with
  `distance=300` still reports "within 50 miles" / "no reporting area". Also the evidence
  that "no data" is a `200` with a `WebServiceError` body.
- `new/forecast_historical__today_ca132.json` — `startDate=2026-09-12&endDate=2026-09-13`
  at 08:39 PDT: five rows valid 2026-09-12, none for the 13th. Compare with
  `new/forecast_current__zip_2026-09-12.json` taken at the same moment, which also had
  nothing valid for the 13th yet. So the historical service serves *today*; future
  validity dates are still unverified (re-probe after the afternoon issuance).
