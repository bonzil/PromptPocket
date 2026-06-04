# PromptPocket

PromptPocket is a tiny macOS floating scratchpad for temporarily moving text out of the currently focused prompt/input field.

It is designed for prompt-heavy workflows: press **Right Command + L** while an input field is focused, and PromptPocket moves the text into an always-on-top note, clears the original field, and leaves the captured text on the clipboard so you can paste it back with **Command + V**.

## Features

- Global hotkey: **Right Command + L**
- Always-on-top floating scratchpad
- Capture focused text and clear the original input
- Leaves captured text on the clipboard for immediate re-paste
- Accessibility-first capture path for native macOS apps
- Keyboard fallback for Codex/Electron/Chromium-style prompt fields:
  - Preferred: `Command + A` → `Command + X`
  - Compatibility fallback: `Command + A` → `Command + C` → `Delete`
- Close hides the panel instead of quitting; use the **Quit** button to exit

## Requirements

- macOS 13 or newer
- Apple Silicon or Intel Mac supported by SwiftPM build output
- Accessibility permission
- Input Monitoring permission for the global hotkey/event tap

## Install from release

1. Download `PromptPocket.dmg` from the latest GitHub Release.
2. Open the DMG and drag `PromptPocket.app` to `/Applications`.
3. Open `/Applications/PromptPocket.app`.
4. Enable permissions:
   - System Settings → Privacy & Security → Accessibility → PromptPocket
   - System Settings → Privacy & Security → Input Monitoring → PromptPocket
5. Restart PromptPocket after granting permissions.

> Note: public builds are currently not Apple Developer ID notarized. macOS may show an unidentified developer warning. If that happens, right-click the app and choose **Open**, or build from source.

## Usage

1. Focus a text input or prompt field.
2. Press **Right Command + L**.
3. PromptPocket appends the captured text to the floating note and clears the original input.
4. If you want to put it back, press **Command + V** immediately.

## Build from source

```sh
swift run --scratch-path .build PromptPocketCoreBehaviorTests
./scripts/build_app.sh
./scripts/build_dmg.sh
hdiutil verify build/PromptPocket.dmg
```

Outputs:

```text
build/PromptPocket.app
build/PromptPocket.dmg
```

### Signing

By default, local and GitHub Actions builds use ad-hoc signing. This avoids
Keychain setup and is enough for building and packaging the app without an Apple
Developer ID certificate.

Public builds are not notarized, so macOS may still show an unidentified
developer warning on first launch.

If you want a stable signing identity for repeated local rebuilds, set your own
signing identity. The identity must already exist in your keychain:

```sh
PROMPTPOCKET_SIGN_IDENTITY="Developer ID Application: Your Name" ./scripts/build_app.sh
```

If you want the helper to create a local self-signed identity, opt in
explicitly:

```sh
PROMPTPOCKET_SIGN_IDENTITY="PromptPocket Local Code Signing" \
PROMPTPOCKET_CREATE_LOCAL_SIGNING_IDENTITY=1 \
PROMPTPOCKET_SIGN_KEYCHAIN="$HOME/Library/Keychains/PromptPocketLocalSigning.keychain-db" \
./scripts/build_app.sh
```

The script does **not** store signing secrets in the repository. Temporary
private key material is created in a temporary directory and removed after
import.

## GitHub Releases

Pushing a version tag such as `v1.0.3` runs the release workflow, builds
`PromptPocket.dmg`, verifies it, writes a SHA256 checksum, and publishes both
files to GitHub Releases.

## Fix duplicate permission rows

If macOS shows duplicate PromptPocket entries or the hotkey still fails after an update:

```sh
./scripts/reset_permissions.sh
./scripts/install_app.sh
open /Applications/PromptPocket.app
```

Then enable the single `/Applications/PromptPocket.app` entry in Accessibility and Input Monitoring.

## Privacy and security

- PromptPocket runs locally.
- It has no network client code and does not send captured text anywhere.
- It reads only the currently focused accessibility element or the temporary keyboard selection used for fallback capture.
- Captured text is stored only in the app's in-memory note and the system clipboard.
- See [SECURITY.md](SECURITY.md) for reporting guidance.

## Architecture

See [docs/architecture.md](docs/architecture.md).

## License

MIT. See [LICENSE](LICENSE).
