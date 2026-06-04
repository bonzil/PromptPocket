#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PromptPocket"
NEW_BUNDLE_ID="com.hwangseonghyeon.promptpocket"
OLD_BUNDLE_ID="local.prompt-pocket"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.5

for volume in /Volumes/PromptPocket*; do
    [[ -e "$volume" ]] || continue
    hdiutil detach "$volume" >/dev/null 2>&1 || true
done

for bundle_id in "$NEW_BUNDLE_ID" "$OLD_BUNDLE_ID"; do
    tccutil reset Accessibility "$bundle_id" >/dev/null 2>&1 || true
    tccutil reset ListenEvent "$bundle_id" >/dev/null 2>&1 || true
    tccutil reset InputMonitoring "$bundle_id" >/dev/null 2>&1 || true
done

if [[ -x "$LSREGISTER" ]]; then
    while IFS= read -r app; do
        [[ -d "$app" ]] || continue
        case "$app" in
            /Applications/PromptPocket.app)
                "$LSREGISTER" -f "$app" >/dev/null 2>&1 || true
                ;;
            *)
                "$LSREGISTER" -u "$app" >/dev/null 2>&1 || true
                ;;
        esac
    done < <(mdfind 'kMDItemFSName == "PromptPocket.app"' 2>/dev/null || true)
fi

echo "PromptPocket permission records reset."
echo "Next: open /Applications/PromptPocket.app once, then enable exactly that PromptPocket in Accessibility and Input Monitoring."
