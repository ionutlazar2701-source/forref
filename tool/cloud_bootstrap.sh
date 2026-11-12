#!/usr/bin/env bash
# FORREF cloud bootstrap — idempotent workspace dependency preparation.
# Assumes Flutter and Dart are already on PATH (or via FVM when installed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "cloud_bootstrap: required command not found: $1" >&2
    exit 1
  fi
}

read_pinned_flutter() {
  if [[ -f "$ROOT/.fvm/fvm_config.json" ]]; then
    grep -o '"flutter"[[:space:]]*:[[:space:]]*"[^"]*"' "$ROOT/.fvm/fvm_config.json" \
      | sed -n 's/.*"\([0-9][^"]*\)".*/\1/p' \
      | head -n1
  fi
}

PINNED_FLUTTER="$(read_pinned_flutter)"
PINNED_DART="3.13.2"

if command -v fvm >/dev/null 2>&1 && [[ -n "$PINNED_FLUTTER" ]]; then
  DART_CMD=(fvm dart)
  FLUTTER_CMD=(fvm flutter)
else
  DART_CMD=(dart)
  FLUTTER_CMD=(flutter)
fi

require_cmd "${DART_CMD[0]}"
require_cmd "${FLUTTER_CMD[0]}"

echo "cloud_bootstrap: repository root = $ROOT"
echo "cloud_bootstrap: dart $("${DART_CMD[@]}" --version 2>&1 | head -n1)"
echo "cloud_bootstrap: flutter $("${FLUTTER_CMD[@]}" --version 2>&1 | head -n1)"

if [[ -n "$PINNED_FLUTTER" ]]; then
  flutter_version="$("${FLUTTER_CMD[@]}" --version 2>&1 | head -n1)"
  if [[ "$flutter_version" != *"$PINNED_FLUTTER"* ]]; then
    echo "cloud_bootstrap: expected Flutter $PINNED_FLUTTER, got: $flutter_version" >&2
    exit 1
  fi
  dart_version="$("${DART_CMD[@]}" --version 2>&1 | head -n1)"
  if [[ "$dart_version" != *"$PINNED_DART"* ]]; then
    echo "cloud_bootstrap: expected Dart $PINNED_DART, got: $dart_version" >&2
    exit 1
  fi
  echo "cloud_bootstrap: pinned toolchain verified (Flutter $PINNED_FLUTTER, Dart $PINNED_DART)"
else
  echo "cloud_bootstrap: warning: no .fvm/fvm_config.json pin found" >&2
fi

echo "cloud_bootstrap: resolving workspace dependencies"
"${DART_CMD[@]}" pub get

echo "cloud_bootstrap: verifying workspace packages resolve"
for pkg in \
  packages/forref_match_core \
  packages/forref_match_persistence \
  apps/referee_phone; do
  if [[ ! -f "$pkg/pubspec.yaml" ]]; then
    echo "cloud_bootstrap: missing pubspec: $pkg/pubspec.yaml" >&2
    exit 1
  fi
done

echo "cloud_bootstrap: complete"
