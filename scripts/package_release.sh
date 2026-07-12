#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
APP_NAME="Codex Island"
DMG_NAME="Codex-Island-v${VERSION}.dmg"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/package_app.sh"

cp -R "$ROOT_DIR/dist/$APP_NAME.app" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$ROOT_DIR/dist/$DMG_NAME" "$ROOT_DIR/dist/$DMG_NAME.sha256"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$ROOT_DIR/dist/$DMG_NAME"
hdiutil verify "$ROOT_DIR/dist/$DMG_NAME"

(
  cd "$ROOT_DIR/dist"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
  shasum -a 256 -c "$DMG_NAME.sha256"
)

echo "$ROOT_DIR/dist/$DMG_NAME"
