#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p reports

MAX_TRIES=2
OUT="reports/repair.json"

printf '[]\n' > "$OUT"

while IFS= read -r REPO
do
  BAD_RUN="$(
    gh run list \
      --repo "$REPO" \
      --status failure \
      --limit 1 \
      --json databaseId,name,url,headSha \
      2>/dev/null ||
    echo '[]'
  )"

  COUNT="$(printf '%s' "$BAD_RUN" | jq 'length')"

  if [ "$COUNT" -eq 0 ]
  then
    echo "✅ $REPO: geen failure"
    continue
  fi

  RUN_ID="$(printf '%s' "$BAD_RUN" | jq -r '.[0].databaseId')"
  RUN_NAME="$(printf '%s' "$BAD_RUN" | jq -r '.[0].name')"

  CLASS="workflow"

  case "$RUN_NAME" in
    *Docker*|*Container*)
      CLASS="container"
      ;;
    *Pages*|*Publish*|*Deploy*)
      CLASS="deployment"
      ;;
    *Security*|*CodeQL*)
      CLASS="security"
      ;;
    *Validate*|*Test*)
      CLASS="testing"
      ;;
  esac

  RESULT="unresolved"

  for TRY in $(seq 1 "$MAX_TRIES")
  do
    echo
    echo "$REPO repair poging $TRY/$MAX_TRIES"

    if gh run rerun "$RUN_ID" \
       --repo "$REPO" \
       --failed \
       >/dev/null 2>&1
    then

      sleep 5

      if timeout 15m \
         gh run watch "$RUN_ID" \
         --repo "$REPO" \
         --exit-status \
         >/dev/null 2>&1
      then
        RESULT="repaired"
        break
      fi

    fi
  done

  jq \
    --arg repo "$REPO" \
    --arg class "$CLASS" \
    --arg result "$RESULT" \
    --arg run "$RUN_ID" \
    '. += [{
      repository:$repo,
      class:$class,
      result:$result,
      run_id:$run
    }]' \
    "$OUT" > "$OUT.tmp"

  mv "$OUT.tmp" "$OUT"

done < <(
  jq -r 'sort_by(.priority)[].repo' config/repos.json
)

jq . "$OUT"
