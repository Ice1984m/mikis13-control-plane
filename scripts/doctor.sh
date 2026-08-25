#!/usr/bin/env bash
set -Eeuo pipefail

FAIL=0

echo
echo "=== Bash ==="

for F in scripts/*.sh
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

if jq empty config/system.json
then
  echo "✅ config/system.json"
else
  echo "❌ config/system.json"
  FAIL=1
fi

echo
echo "=== Security ==="

if timeout 60s ./scripts/security.sh
then
  echo "✅ Security"
else
  echo "❌ Security"
  FAIL=1
fi

echo
echo "=== Site ==="

SITE="$(jq -r '.site_dir' config/system.json)"

for F in \
  index.html \
  control-plane.html
do

  if [ -s "$SITE/$F" ]
  then
    echo "✅ $F"
  else
    echo "❌ $F"
    FAIL=1
  fi

done

echo
echo "=== Git secret-status ==="

cd "$SITE"

if [ -f .env ]
then

  if git check-ignore -q .env
  then
    echo "✅ .env lokaal + ignored"
  else
    echo "❌ .env bestaat maar wordt niet genegeerd"
    FAIL=1
  fi

fi

echo
echo "================================"

if [ "$FAIL" -eq 0 ]
then
  echo "✅ DOCTOR PASS"
  exit 0
else
  echo "❌ DOCTOR FAIL"
  exit 1
fi
