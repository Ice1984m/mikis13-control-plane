#!/usr/bin/env bash
set -Eeuo pipefail

BASE="https://mikis13.nl"

PATHS=(
  "/"
  "/nieuws.html"
  "/shop.html"
  "/contact.html"
  "/privacy.html"
  "/voorwaarden.html"
)

FAIL=0

for PATHNAME in "${PATHS[@]}"
do
  URL="$BASE$PATHNAME"

  TMP="$(mktemp)"

  set +e

  RESULT="$(
    curl \
      -L \
      -sS \
      --connect-timeout 8 \
      --max-time 20 \
      -o "$TMP" \
      -w '%{http_code}|%{url_effective}' \
      "$URL" \
      2>/dev/null
  )"

  RC=$?

  set -e

  if [ "$RC" -ne 0 ]
  then
    echo "❌ CURL rc=$RC $URL"
    FAIL=1
    rm -f "$TMP"
    continue
  fi

  CODE="${RESULT%%|*}"
  FINAL="${RESULT#*|}"

  case "$CODE" in
    200)
      echo "✅ HTTP 200 $URL"
      echo "   -> $FINAL"
      ;;
    301|302|307|308)
      echo "ℹ️ HTTP $CODE $URL"
      echo "   -> $FINAL"
      ;;
    *)
      echo "⚠️ HTTP $CODE $URL"
      echo "   -> $FINAL"
      FAIL=1
      ;;
  esac

  rm -f "$TMP"
done

exit "$FAIL"
