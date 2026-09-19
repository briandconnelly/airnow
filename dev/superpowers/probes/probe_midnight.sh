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
