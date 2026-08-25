#!/usr/bin/env bash
set -Eeuo pipefail

SITE="$(jq -r '.site_dir' config/system.json)"

PATTERN='sk-proj-[A-Za-z0-9_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}'

FOUND=0

echo
echo "=== MIKIS13 SECURITY SCAN ==="

cd "$SITE"

# ------------------------------------------------------------
# Alleen bestanden controleren die Git daadwerkelijk ziet.
#
# Dit scant:
# - tracked bestanden
# - nieuwe niet-genegeerde bestanden
#
# Dit scant NIET:
# - .env die correct in .gitignore staat
# - node_modules
# - .git
# - andere ignored lokale secrets
# ------------------------------------------------------------

while IFS= read -r FILE
do
  [ -n "$FILE" ] || continue
  [ -f "$FILE" ] || continue

  case "$FILE" in
    node_modules/*|.git/*)
      continue
      ;;
  esac

  if grep -E "$PATTERN" "$FILE" >/dev/null 2>&1
  then
    echo "❌ Mogelijke echte secret in Git-bestand: $FILE"
    FOUND=1
  fi

done < <(
  {
    git ls-files
    git ls-files \
      --others \
      --exclude-standard
  } |
  sort -u
)

# ------------------------------------------------------------
# Extra controle: .env mag NOOIT tracked zijn.
# ------------------------------------------------------------

for SECRET_FILE in \
  .env \
  openai.key \
  security.env
do

  if git ls-files --error-unmatch "$SECRET_FILE" >/dev/null 2>&1
  then
    echo "❌ Verboden secretbestand is tracked: $SECRET_FILE"
    FOUND=1
  fi

done

if [ "$FOUND" -ne 0 ]
then
  echo
  echo "❌ SECURITY SCAN FAILED"
  exit 1
fi

echo "✅ Geen herkenbare secrets in publiceerbare Git-bestanden"
