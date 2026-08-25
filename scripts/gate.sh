#!/usr/bin/env bash
set -Eeuo pipefail

echo
echo "========================================"
echo " MIKIS13 RELEASE GATE"
echo "========================================"

./scripts/security.sh
./scripts/status.sh >/dev/null
./tests/e2e.sh

BAD_REPOS="$(
  jq '
    [
      .repositories[]
      | select(.status=="warning" or .status=="unreachable")
    ]
    | length
  ' reports/status.json
)"

DOWN_URLS="$(
  jq '
    [
      .urls[]
      | select(.health=="down")
    ]
    | length
  ' reports/status.json
)"

[ "$BAD_REPOS" -eq 0 ] || {
  echo "❌ Repository gate geblokkeerd"
  exit 1
}

[ "$DOWN_URLS" -eq 0 ] || {
  echo "❌ Live gate geblokkeerd"
  exit 1
}

echo "✅ RELEASE GATE GROEN"
