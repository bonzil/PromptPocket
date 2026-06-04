# Contributing

Thanks for helping improve PromptPocket.

## Development loop

```sh
swift run --scratch-path .build PromptPocketCoreBehaviorTests
swift build -c release --product PromptPocket --scratch-path .build
./scripts/build_app.sh
```

## Before opening a PR

- Keep app behavior local-only; do not add network calls or analytics.
- Do not commit `.build/`, `build/`, `.app`, `.dmg`, keychains, certificates, tokens, or local permission databases.
- Update README/docs when capture flow, fallback order, clipboard behavior, or permissions change.
- Run the behavior tests and release build.

## Commit style

Use concise conventional commits when practical, for example:

```text
fix: improve Codex prompt capture fallback
docs: document Input Monitoring permissions
```
