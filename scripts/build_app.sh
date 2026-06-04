#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="PromptPocket"
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE="$BUILD_DIR/ModuleCache"

mkdir -p "$MODULE_CACHE" "$PROJECT_DIR/build"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

build_product() {
    swift build -c release --product "$APP_NAME" --scratch-path "$BUILD_DIR"
}

if ! build_product; then
    echo "SwiftPM normal build failed; retrying with --disable-sandbox..." >&2
    swift build --disable-sandbox -c release --product "$APP_NAME" --scratch-path "$BUILD_DIR"
fi

BIN_DIR="$(swift build -c release --scratch-path "$BUILD_DIR" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
    echo "Missing executable: $EXECUTABLE_PATH" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

ICON_PATH="$RESOURCES_DIR/AppIcon.icns"
SOURCE_ICON="$PROJECT_DIR/Resources/AppIcon.icns"
if [[ -f "$SOURCE_ICON" ]]; then
    cp "$SOURCE_ICON" "$ICON_PATH"
else
    ICONSET_DIR="$PROJECT_DIR/build/AppIcon.iconset"
    swift "$PROJECT_DIR/scripts/make_icon.swift" "$ICONSET_DIR"
    iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko</string>
    <key>CFBundleDisplayName</key>
    <string>PromptPocket</string>
    <key>CFBundleExecutable</key>
    <string>PromptPocket</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.hwangseonghyeon.promptpocket</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PromptPocket</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>PromptPocket needs Accessibility permission to read and clear the focused input field when you press Right Command + L.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>PromptPocket needs Input Monitoring permission to detect Right Command + L while another app's input field is focused.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"

SIGN_IDENTITY="${PROMPTPOCKET_SIGN_IDENTITY:-PromptPocket Local Code Signing}"
if [[ -z "${PROMPTPOCKET_SIGN_IDENTITY:-}" || "${PROMPTPOCKET_CREATE_LOCAL_SIGNING_IDENTITY:-0}" == "1" ]]; then
    "$PROJECT_DIR/scripts/ensure_local_signing_identity.sh"
fi

SIGN_VALUE="$SIGN_IDENTITY"
if [[ -n "${PROMPTPOCKET_SIGN_KEYCHAIN:-}" ]]; then
    SIGN_HASH="$(python3 - "$PROMPTPOCKET_SIGN_KEYCHAIN" "$SIGN_IDENTITY" <<'PY'
import re
import subprocess
import sys
keychain, identity = sys.argv[1], sys.argv[2]
out = subprocess.check_output(['security', 'find-certificate', '-c', identity, '-Z', keychain], text=True, stderr=subprocess.DEVNULL)
match = re.search(r'SHA-1 hash:\s*([A-Fa-f0-9]+)', out)
if match:
    print(match.group(1))
PY
)"
    if [[ -z "$SIGN_HASH" ]]; then
        echo "Missing signing identity in keychain: $SIGN_IDENTITY ($PROMPTPOCKET_SIGN_KEYCHAIN)" >&2
        exit 1
    fi
    SIGN_VALUE="$SIGN_HASH"
fi

xattr -cr "$APP_DIR"
CODESIGN_ARGS=(--force --deep --sign "$SIGN_VALUE")
if [[ -n "${PROMPTPOCKET_SIGN_KEYCHAIN:-}" ]]; then
    CODESIGN_ARGS+=(--keychain "$PROMPTPOCKET_SIGN_KEYCHAIN")
fi
codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
xattr -cr "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built $APP_DIR"
