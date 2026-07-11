#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_DIR="$ROOT_DIR/.build/$CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/Codex Island.app"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/CodexIsland" "$APP_DIR/Contents/MacOS/CodexIsland"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/CodexIsland.icns" "$APP_DIR/Contents/Resources/CodexIsland.icns"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
