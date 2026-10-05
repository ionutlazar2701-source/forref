#!/usr/bin/env bash
# FORREF cloud bootstrap — idempotent workspace dependency preparation.
# Installs the pinned Flutter SDK and Linux desktop libraries when missing,
# then resolves workspace packages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
PINNED_DART="3.13.2"

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

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

ensure_system_packages() {
  local packages=(
    ca-certificates
    curl
    git
    unzip
    xz-utils
    zip
    libglu1-mesa
    clang
    cmake
    ninja-build
    pkg-config
    libgtk-3-dev
    liblzma-dev
    libsqlite3-dev
  )
  local missing=()
  local pkg
  for pkg in "${packages[@]}"; do
    if ! pkg_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]} == 0)); then
    echo "cloud_bootstrap: system packages already present"
    return 0
  fi
  echo "cloud_bootstrap: installing system packages: ${missing[*]}"
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

flutter_version_line() {
  flutter --version 2>&1 | head -n1 || true
}

dart_version_line() {
  dart --version 2>&1 | head -n1 || true
}

ensure_flutter() {
  local pinned="$1"
  if command -v flutter >/dev/null 2>&1; then
    local current
    current="$(flutter_version_line)"
    if [[ "$current" == *"$pinned"* ]]; then
      echo "cloud_bootstrap: Flutter $pinned already on PATH ($current)"
      return 0
    fi
    echo "cloud_bootstrap: replacing Flutter ($current) with $pinned"
  else
    echo "cloud_bootstrap: installing Flutter $pinned"
  fi

  local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${pinned}-stable.tar.xz"
  local tmp
  tmp="$(mktemp -d)"
  echo "cloud_bootstrap: downloading $url"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp/flutter.tar.xz" "$url"
  sudo rm -rf "$FLUTTER_HOME"
  sudo tar -xJf "$tmp/flutter.tar.xz" -C /opt
  rm -rf "$tmp"
  if [[ ! -x /opt/flutter/bin/flutter ]]; then
    echo "cloud_bootstrap: Flutter archive did not contain /opt/flutter/bin/flutter" >&2
    exit 1
  fi
  sudo chown -R "$(id -un):$(id -gn)" /opt/flutter
  sudo ln -sfn /opt/flutter/bin/flutter /usr/local/bin/flutter
  sudo ln -sfn /opt/flutter/bin/dart /usr/local/bin/dart
  hash -r
}

configure_flutter() {
  if ! git config --global --get-all safe.directory 2>/dev/null | grep -qx "$FLUTTER_HOME"; then
    git config --global --add safe.directory "$FLUTTER_HOME"
  fi
  # Non-interactive. Do not prompt for analytics or version checks.
  flutter config --no-analytics --no-cli-animations >/dev/null
  dart --disable-analytics >/dev/null 2>&1 || true
  echo "cloud_bootstrap: precaching Linux desktop artifacts"
  flutter precache --linux
}

PINNED_FLUTTER="$(read_pinned_flutter)"
if [[ -z "$PINNED_FLUTTER" ]]; then
  echo "cloud_bootstrap: warning: no .fvm/fvm_config.json pin found" >&2
  echo "cloud_bootstrap: Flutter install skipped; dart and flutter must already be on PATH" >&2
else
  ensure_system_packages
  ensure_flutter "$PINNED_FLUTTER"
  configure_flutter
fi

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
