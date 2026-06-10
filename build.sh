#!/usr/bin/env bash
# Build Droply.app bundle from SwiftPM executable.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-release}"
APP_NAME="Droply"
BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build"
OUT_DIR="dist"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "binary not found: $BIN_PATH" >&2
    exit 1
fi

rm -rf "$OUT_DIR/$BUNDLE"
mkdir -p "$OUT_DIR/$BUNDLE/Contents/MacOS"
mkdir -p "$OUT_DIR/$BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$OUT_DIR/$BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$OUT_DIR/$BUNDLE/Contents/Info.plist"

# Ad-hoc sign so Gatekeeper does not reject on launch.
codesign --force --deep --sign - "$OUT_DIR/$BUNDLE" >/dev/null 2>&1 || true

echo "==> built: $OUT_DIR/$BUNDLE"
echo "run:  open $OUT_DIR/$BUNDLE"
