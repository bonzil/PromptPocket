# Security Policy

## Supported versions

PromptPocket is early-stage software. Security fixes are applied to the latest public release and the `main` branch.

## Privacy model

PromptPocket is intentionally local-only:

- No analytics
- No network requests
- No cloud sync
- No persistent prompt history file
- Captured text is kept in memory and placed on the macOS clipboard after capture

The app needs Accessibility and Input Monitoring permissions because it must detect a global hotkey and interact with the currently focused input field.

## Reporting a vulnerability

Please open a GitHub issue with a clear description and reproduction steps.

Do **not** include private prompts, API keys, passwords, or other sensitive text in public reports. If a reproduction needs sensitive content, reduce it to a minimal dummy example first.

## Build and signing notes

The repository does not contain private signing keys, certificates, tokens, or GitHub secrets.

Local builds can create a self-signed code-signing identity so macOS TCC permissions remain stable across rebuilds. This identity is generated on the builder's machine and should not be committed. Temporary private key material is created in a temporary directory and removed after import.

If you isolate the identity in a custom keychain via `PROMPTPOCKET_SIGN_KEYCHAIN`, use that keychain only for local PromptPocket signing material.

Public release builds are currently not Apple Developer ID notarized.
