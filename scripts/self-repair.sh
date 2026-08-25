#!/usr/bin/env bash
set -Eeuo pipefail

MAX=3

for TRY in $(seq 1 "$MAX")
do
  echo
  echo "Repair ronde $TRY/$MAX"

  chmod +x scripts/*.sh tests/*.sh

  if ./scripts/doctor.sh
  then
    echo "✅ Doctor geslaagd"
    exit 0
  fi

  echo "⚠️ Doctor vond problemen"

  # Repareer permissies.
  chmod +x scripts/*.sh tests/*.sh

  # Zorg dat rapportmappen bestaan.
  mkdir -p reports history releases state

done

echo "❌ Self-repair kon probleem niet oplossen"
exit 1
