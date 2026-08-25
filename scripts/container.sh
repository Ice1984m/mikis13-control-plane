#!/usr/bin/env bash
set -Eeuo pipefail

REPO="Ice1984m/mikis13-container-bot"

echo
echo "=== CONTAINER STATUS ==="

if ! gh repo view "$REPO" >/dev/null 2>&1
then
  echo "⚠️ Container repo bestaat niet"
  exit 0
fi

gh workflow list --repo "$REPO" || true

echo

gh run list \
  --repo "$REPO" \
  --limit 10 || true

echo
echo "Image:"
echo "ghcr.io/ice1984m/mikis13-site:latest"
