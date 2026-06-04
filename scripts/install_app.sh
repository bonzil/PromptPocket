#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PromptPocket"
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"

"$PROJECT_DIR/scripts/build_app.sh"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

rm -rf "$INSTALL_DIR"
ditto --noextattr --norsrc "$APP_DIR" "$INSTALL_DIR"
xattr -cr "$INSTALL_DIR"
codesign --verify --deep --strict --verbose=2 "$INSTALL_DIR"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$INSTALL_DIR" >/dev/null 2>&1 || true
fi

echo "Installed $INSTALL_DIR"
echo "Run scripts/reset_permissions.sh once if macOS still shows duplicate PromptPocket permission entries."
