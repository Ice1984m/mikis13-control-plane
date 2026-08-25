#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p reports history

OUT="reports/status.json"

jq -n \
  --arg timestamp "$(date -u +%FT%TZ)" \
  '{
    timestamp:$timestamp,
    repositories:[],
    urls:[]
  }' > "$OUT"

while IFS= read -r ITEM
do
  NAME="$(printf '%s' "$ITEM" | jq -r '.name')"
  REPO="$(printf '%s' "$ITEM" | jq -r '.repo')"

  SHA="$(
    gh api "repos/$REPO/commits/main" \
      --jq '.sha' 2>/dev/null ||
    echo unavailable
  )"

  RUNS="$(
    gh run list \
      --repo "$REPO" \
      --limit 10 \
      --json name,status,conclusion,databaseId,createdAt,url \
      2>/dev/null ||
    echo '[]'
  )"

  LATEST="$(
    printf '%s' "$RUNS" |
    jq -r '
      [
        .[]
        | select(.status=="completed")
      ]
      | sort_by(.createdAt)
      | reverse
      | .[0].conclusion // "unknown"
    '
  )"

  case "$LATEST" in
    success|neutral|skipped)
      HEALTH="healthy"
      ;;
    failure|timed_out|action_required|cancelled)
      HEALTH="warning"
      ;;
    *)
      HEALTH="unknown"
      ;;
  esac

  jq \
    --arg name "$NAME" \
    --arg repo "$REPO" \
    --arg sha "$SHA" \
    --arg status "$HEALTH" \
    --arg latest "$LATEST" \
    --argjson runs "$RUNS" \
    '.repositories += [{
      name:$name,
      repository:$repo,
      sha:$sha,
      status:$status,
      latest_conclusion:$latest,
      workflows:$runs
    }]' \
    "$OUT" > "$OUT.tmp"

  mv "$OUT.tmp" "$OUT"

done < <(
  jq -c 'sort_by(.priority)[]' config/repos.json
)

while IFS= read -r ITEM
do
  NAME="$(printf '%s' "$ITEM" | jq -r '.name')"
  URL="$(printf '%s' "$ITEM" | jq -r '.url')"

  TMP="$(mktemp)"

  set +e

  RESULT="$(
    curl \
      -L \
      -sS \
      --connect-timeout 8 \
      --max-time 20 \
      -o "$TMP" \
      -w '%{http_code}|%{url_effective}|%{time_total}' \
      "$URL" \
      2>/dev/null
  )"

  RC=$?

  set -e

  if [ "$RC" -eq 0 ]
  then
    CODE="${RESULT%%|*}"
    REST="${RESULT#*|}"
    FINAL="${REST%%|*}"
    TOTAL="${RESULT##*|}"

    case "$CODE" in
      200|204)
        HEALTH="healthy"
        ;;
      301|302|307|308)
        HEALTH="redirect"
        ;;
      *)
        HEALTH="warning"
        ;;
    esac
  else
    CODE="000"
    FINAL="$URL"
    TOTAL="0"
    HEALTH="down"
  fi

  jq \
    --arg name "$NAME" \
    --arg url "$URL" \
    --arg final "$FINAL" \
    --arg code "$CODE" \
    --arg health "$HEALTH" \
    --arg total "$TOTAL" \
    '.urls += [{
      name:$name,
      url:$url,
      final_url:$final,
      http:$code,
      health:$health,
      time_seconds:($total|tonumber? // 0)
    }]' \
    "$OUT" > "$OUT.tmp"

  mv "$OUT.tmp" "$OUT"
  rm -f "$TMP"

done < <(
  jq -c '.[]' config/urls.json
)

cp "$OUT" \
  "history/status-$(date -u +%Y%m%dT%H%M%SZ).json"

jq . "$OUT"
