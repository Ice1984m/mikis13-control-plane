#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p reports

OUT="reports/drift.json"

printf '[]\n' > "$OUT"

while IFS= read -r REPO
do
  LOCAL_DIR="$HOME/${REPO##*/}"

  REMOTE_SHA="$(
    gh api \
      "repos/$REPO/commits/main" \
      --jq '.sha' \
      2>/dev/null ||
    echo unavailable
  )"

  LOCAL_SHA="not-present"
  MODE="termux"

  if [ -d "$LOCAL_DIR/.git" ]
  then
    LOCAL_SHA="$(
      git -C "$LOCAL_DIR" rev-parse HEAD \
      2>/dev/null ||
      echo invalid
    )"
  fi

  if [ "${GITHUB_ACTIONS:-false}" = "true" ] &&
     [ "$LOCAL_SHA" = "not-present" ]
  then
    DRIFT=false
    MODE="cloud-no-local-copy"
  elif [ "$REMOTE_SHA" = "$LOCAL_SHA" ]
  then
    DRIFT=false
  else
    DRIFT=true
  fi

  jq \
    --arg repo "$REPO" \
    --arg remote "$REMOTE_SHA" \
    --arg local "$LOCAL_SHA" \
    --arg mode "$MODE" \
    --argjson drift "$DRIFT" \
    '. += [{
      repository:$repo,
      remote_sha:$remote,
      local_sha:$local,
      mode:$mode,
      drift:$drift
    }]' \
    "$OUT" > "$OUT.tmp"

  mv "$OUT.tmp" "$OUT"

done < <(
  jq -r '.[].repo' config/repos.json
)

jq . "$OUT"
