#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-status}"

case "$MODE" in
  status)
    ./scripts/status.sh
    ;;
  security)
    ./scripts/security.sh
    ;;
  e2e)
    ./tests/e2e.sh
    ;;
  repair)
    ./scripts/repair.sh
    ;;
  self-repair)
    ./scripts/self-repair.sh
    ;;
  container)
    ./scripts/container.sh
    ;;
  history)
    ./scripts/history.sh
    ;;
  drift)
    ./scripts/drift.sh
    ;;
  gate)
    ./scripts/gate.sh
    ;;
  release)
    ./scripts/release.sh "${2:-}"
    ;;
  doctor)
    ./scripts/doctor.sh
    ;;
  full)
    ./scripts/doctor.sh
    ./scripts/status.sh
    ./scripts/container.sh
    ./scripts/drift.sh
    ./tests/e2e.sh || true
    ./scripts/history.sh
    ;;
  *)
    echo "status"
    echo "security"
    echo "e2e"
    echo "repair"
    echo "self-repair"
    echo "container"
    echo "history"
    echo "drift"
    echo "gate"
    echo "release"
    echo "doctor"
    echo "full"
    exit 1
    ;;
esac
