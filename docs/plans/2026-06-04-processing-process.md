# PromptPocket processing process

Goal: move text from the currently focused prompt/input field into an always-on-top scratchpad with **Right Command + L**, clear the original field, and leave the captured text on the clipboard for immediate re-paste.

## Flow

1. App launch
   - Runs as a macOS accessory app.
   - Creates a floating 4.3:3 panel that can join all Spaces/fullscreen contexts.
   - Requests Accessibility permission.
   - Registers a global event tap for the hotkey.

2. Hotkey detection
   - `CGEventTap` watches keyDown events.
   - Only `Right Command + L` is consumed.
   - Other keyboard events pass through unchanged.

3. Text capture and clearing
   - First path: Accessibility API reads the focused element's `AXValue` and clears it by setting `AXValue` to an empty string.
   - Fallback path 1: `Command + A` → `Command + X` for Codex/Electron/Chromium-like prompt fields.
   - Fallback path 2: `Command + A` → `Command + C` → `Delete` for compatibility when Cut is unavailable.

4. Note and clipboard update
   - Non-empty captured text is appended to `NoteBuffer` with a blank-line separator.
   - The floating panel is brought forward.
   - The captured text becomes the final system clipboard string so `Command + V` can paste it back immediately.

5. Packaging
   - SwiftPM builds the release binary.
   - Scripts assemble `PromptPocket.app` and `PromptPocket.dmg`.
   - Local signing keeps the bundle identity stable for TCC permissions during local rebuilds.

## Verification

- `swift run --scratch-path .build PromptPocketCoreBehaviorTests`
- `swift build -c release --product PromptPocket --scratch-path .build`
- `./scripts/build_app.sh`
- `./scripts/build_dmg.sh`
- `hdiutil verify build/PromptPocket.dmg`
