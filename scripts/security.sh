#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p reports

PATTERN='sk-proj-[A-Za-z0-9_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}'

FOUND=0

while IFS= read -r FILE
do
  [ -f "$FILE" ] || continue

  case "$FILE" in
    ./scripts/security.sh)
      continue
      ;;
  esac

  if grep -E "$PATTERN" "$FILE" >/dev/null 2>&1
  then
    echo "❌ Mogelijke echte secret: $FILE"
    FOUND=1
  fi

done < <(
  find . \
    -type f \
    ! -path './.git/*' \
    ! -path './history/*' \
    ! -path './reports/*'
)

jq -n \
  --arg time "$(date -u +%FT%TZ)" \
  --argjson found "$FOUND" \
  '{
    timestamp:$time,
    secret_scan_failures:$found
  }' > reports/security.json

[ "$FOUND" -eq 0 ] || exit 1

echo "✅ Security scan OK"
