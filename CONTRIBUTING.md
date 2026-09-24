# Contributing

## Toolchain

Flutter `3.44.7`, stable channel. Match the pin in `.github/workflows/ci.yml`;
a different version can pass locally and fail CI (or vice versa) on formatter
or analyzer output.

## Before opening a PR

```
make check
```

runs, in order: `dart format --output=none --set-exit-if-changed .`,
`flutter analyze --fatal-infos`, `flutter test -x golden`. All three must be
clean; CI runs the same three plus a Linux release build.

## Adding a new source (provider)

Every provider that fetches from a network API ships with a fixture captured
from a real response, not a hand-written one: fixtures live flat under
`test/fixtures/` (e.g. `test/fixtures/webdock_server.json`), and the
provider's test decodes the fixture file and feeds it through a
`MockClient`. Follow the shape of an existing provider
(`lib/features/vps/data/webdock_source.dart` is the reference for error
mapping). See `docs/PROVIDERS.md` once Phase 2 lands for the "4 files" recipe.

## Commit style

Conventional-commit prefixes going forward (`feat:`, `fix:`, `docs:`,
`chore:`, `refactor:`, `test:`) so `git-cliff` can group release notes by
type. History before this file predates the convention and is not being
rewritten.

## Code style

- No comments unless the WHY is non-obvious (a hidden constraint, a subtle
  invariant, a workaround for a specific bug).
- Prefer editing an existing file over adding a new abstraction.
