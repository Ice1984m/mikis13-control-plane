#!/usr/bin/env bash
set -Eeuo pipefail

FAIL=0

echo "=== Bash ==="

for F in scripts/*.sh tests/*.sh
do
  if bash -n "$F"
  then
    echo "✅ $F"
  else
    echo "❌ $F"
    FAIL=1
  fi
done

echo
echo "=== JSON ==="

jq empty config/repos.json || FAIL=1
jq empty config/urls.json || FAIL=1

echo
echo "=== Required ==="

for F in \
  README.md \
  public/index.html \
  .github/workflows/control-plane.yml \
  .github/workflows/release-gate.yml
do
  if [ -s "$F" ]
  then
    echo "✅ $F"
  else
    echo "❌ $F"
    FAIL=1
  fi
done

echo
echo "=== Security ==="

./scripts/security.sh || FAIL=1

exit "$FAIL"
