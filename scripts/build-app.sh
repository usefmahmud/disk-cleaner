#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="SpaceSweep"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

cd "$ROOT"

echo "Building $APP_NAME ($CONFIGURATION)…"
swift build -c "$CONFIGURATION" --product "$APP_NAME"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BINARY="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BINARY" ]]; then
    echo "Build succeeded but the executable was not found at $BINARY" >&2
    exit 1
fi

echo "Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS_DIR/$APP_NAME"
chmod 755 "$MACOS_DIR/$APP_NAME"
cp "$ROOT/Support/Info.plist" "$CONTENTS/Info.plist"

ICONSET_ROOT="$(mktemp -d "${TMPDIR:-/private/tmp}/spacesweep-icon.XXXXXX")"
trap 'rm -rf "$ICONSET_ROOT"' EXIT
ICONSET="$ICONSET_ROOT/AppIcon.iconset"

echo "Drawing app icon…"
swift "$ROOT/scripts/make-icon.swift" "$ICONSET" >/dev/null
iconutil --convert icns --output "$RESOURCES_DIR/AppIcon.icns" "$ICONSET"

# Ad-hoc signing keeps the app launchable after a local build and gives macOS a
# stable identity for Privacy & Security permissions on this machine.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || {
    echo "warning: ad-hoc code signing failed; the app may still launch." >&2
}

echo "Built $APP_DIR"
