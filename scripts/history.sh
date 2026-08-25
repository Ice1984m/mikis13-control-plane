#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p history reports

if [ ! -s reports/status.json ]
then
  ./scripts/status.sh >/dev/null
fi

OUT="history/summary-$(date -u +%Y%m%dT%H%M%SZ).json"

jq \
  --arg timestamp "$(date -u +%FT%TZ)" \
  '{
    timestamp:$timestamp,
    healthy_urls:(
      [.urls[] | select(.health=="healthy")]
      | length
    ),
    down_urls:(
      [.urls[] | select(.health=="down")]
      | length
    ),
    warning_repositories:(
      [.repositories[] | select(.status=="warning")]
      | length
    )
  }' \
  reports/status.json \
  > "$OUT"

echo "✅ Historiek bijgewerkt"
