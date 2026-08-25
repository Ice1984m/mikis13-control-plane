#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="${1:-}"

if [ -z "$VERSION" ]
then
  VERSION="v$(date +%Y.%m.%d.%H%M)"
fi

./scripts/gate.sh

mkdir -p releases

FILE="releases/$VERSION.md"

{
  echo "# Mikis13 Control Plane $VERSION"
  echo
  echo "Datum: $(date -u +%FT%TZ)"
  echo
  echo "## Resultaat"
  echo
  echo "- Security gate: PASS"
  echo "- E2E gate: PASS"
  echo "- Repository gate: PASS"
  echo "- Live gate: PASS"
} > "$FILE"

if gh release view "$VERSION" >/dev/null 2>&1
then
  echo "ℹ️ Release bestaat al"
else
  gh release create "$VERSION" \
    --title "Mikis13 Control Plane $VERSION" \
    --notes-file "$FILE"
fi

echo "✅ Release $VERSION klaar"
