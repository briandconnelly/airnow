#!/bin/bash
set -euo pipefail

KEY="${AIRNOW_API_TOKEN:?not set}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${AIRNOW_PROBE_OUT:-$HERE/new}"
mkdir -p "$OUT"

hit () {  # name  url  keyparam  extra-args...
  local name="$1" url="$2" keyparam="$3"; shift 3
  local code
  code=$(curl -sS -G "$url" \
      --data-urlencode "format=application/json" \
      --data-urlencode "${keyparam}=${KEY}" \
      "$@" \
      -o "$OUT/$name.json" -w '%{http_code}' --max-time 45 2>"$OUT/$name.err")
  printf '%-34s HTTP %s  %6s bytes\n' "$name" "$code" "$(wc -c <"$OUT/$name.json" | tr -d ' ')"
}

B=https://www.airnowapi.org

hit fc_current_zip      "$B/aq/forecast/current/"                api_key -d zipCode=90210
hit fc_current_https    "https://www.airnowapi.org/aq/forecast/current/" api_key -d zipCode=90210
hit obs_ziplatLong      "$B/aq/observation/current/ziplatLong"   api_key -d zipCode=90210
hit obs_ziplatlong_lc   "$B/aq/observation/current/ziplatlong"   api_key -d zipCode=90210
hit obs_ziplatLong_slash "$B/aq/observation/current/ziplatLong/" api_key -d zipCode=90210
hit obs_racode          "$B/aq/observation/current/racode"       api_key -d reportingAreaCode=ca064
hit fc_hist_apiKey      "$B/aq/forecast/historical/"             apiKey  -d reportingAreaCode=md008 -d startDate=2026-01-13 -d endDate=2026-01-14
hit fc_hist_api_key     "$B/aq/forecast/historical/"             api_key -d reportingAreaCode=md008 -d startDate=2026-01-13 -d endDate=2026-01-14
hit obs_hist_state      "$B/aq/observation/historical/state/"    api_key -d stateCode=MD -d startDate=2026-04-21 -d endDate=2026-04-21
hit dailydata_A         "$B/aq/dailydata/"                       api_key -d startDate=2026-02-07 -d endDate=2026-02-07 -d maxlat=43.584173 -d minlat=43.548351 -d maxlon=-70.175682 -d minlon=-70.234046 -d parameters=ozone -d datatype=A
