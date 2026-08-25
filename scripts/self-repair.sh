#!/usr/bin/env bash
set -Eeuo pipefail

MAX=3

for TRY in $(seq 1 "$MAX")
do

  echo
  echo "================================"
  echo " SELF REPAIR $TRY/$MAX"
  echo "================================"

  chmod +x scripts/*.sh

  mkdir -p \
    reports \
    history \
    backups \
    state

  if ./scripts/doctor.sh
  then
    echo
    echo "✅ SELF REPAIR PASS"
    exit 0
  fi

  echo
  echo "⚠️ Doctor faalde."

  # Alleen veilige generieke repairs.
  chmod +x scripts/*.sh

  sleep 2

done

echo
echo "❌ Self repair kon een echte inhoudelijke fout niet automatisch oplossen."
exit 1
