#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PromptPocket"
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
DMG_ROOT="$PROJECT_DIR/build/dmg-root"
DMG_PATH="$PROJECT_DIR/build/$APP_NAME.dmg"

"$PROJECT_DIR/scripts/build_app.sh"

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
ditto --noextattr --norsrc "$APP_DIR" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
xattr -cr "$DMG_ROOT"

TMP_DMG="$PROJECT_DIR/build/$APP_NAME.tmp.$$.dmg"
rm -f "$TMP_DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$TMP_DMG"
mv -f "$TMP_DMG" "$DMG_PATH"

echo "Built $DMG_PATH"
