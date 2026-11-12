#!/usr/bin/env bash
# Canonical FORREF cloud-capable verification command.
# Run from repository root: ./tool/verify_cloud.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if command -v fvm >/dev/null 2>&1 && [[ -f "$ROOT/.fvm/fvm_config.json" ]]; then
  DART=(fvm dart)
  FLUTTER=(fvm flutter)
else
  DART=(dart)
  FLUTTER=(flutter)
fi

FAILED=0

run_step() {
  local label="$1"
  shift
  echo ""
  echo "=== $label ==="
  if "$@"; then
    echo "=== PASS: $label ==="
  else
    echo "=== FAIL: $label ===" >&2
    FAILED=1
  fi
}

echo "verify_cloud: repository root = $ROOT"

run_step "cloud bootstrap" "$ROOT/tool/cloud_bootstrap.sh"

run_step "analyze packages/forref_match_core" \
  bash -lc "cd '$ROOT/packages/forref_match_core' && ${DART[*]} analyze"

run_step "test packages/forref_match_core" \
  bash -lc "cd '$ROOT/packages/forref_match_core' && ${DART[*]} test"

run_step "analyze packages/forref_match_persistence" \
  bash -lc "cd '$ROOT/packages/forref_match_persistence' && ${DART[*]} analyze"

run_step "test packages/forref_match_persistence" \
  bash -lc "cd '$ROOT/packages/forref_match_persistence' && ${DART[*]} test"

run_step "analyze apps/referee_phone" \
  bash -lc "cd '$ROOT/apps/referee_phone' && ${FLUTTER[*]} analyze"

run_step "test apps/referee_phone" \
  bash -lc "cd '$ROOT/apps/referee_phone' && ${FLUTTER[*]} test"

echo ""
if [[ "$FAILED" -ne 0 ]]; then
  echo "verify_cloud: FAILED — one or more cloud-capable suites did not pass." >&2
  exit 1
fi

echo "verify_cloud: PASSED — all cloud-capable suites succeeded."
exit 0
