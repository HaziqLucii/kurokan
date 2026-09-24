# Kurokan — Claude Code instructions

Flutter desktop dashboard (macOS + Linux), Swiss-Japanese monochrome UI.
Package name `kurokan`, repo `HaziqLucii/kurokan`. See `README.md` for the
pitch, `docs/DECISIONS.md` for the decisions log, `docs/ROADMAP.md` for the
public phase checklist, and `CONTRIBUTING.md` for the human-contributor
workflow. The active build plan (if one exists) lives under `plans/`,
gitignored, local-only — check there before starting new feature work.

## Before every commit

```
make check
```

Format, `flutter analyze --fatal-infos`, and tests must all be clean. CI runs
the same three plus a Linux release build and a macOS compile-only check —
if `make check` is green locally, CI should be green too.

## Test coverage is not optional

Every PR gets a Codecov patch-coverage comment. A red `❌ Patch coverage`
comment is not a blocking CI check, but it is a real signal — do not ignore
it and do not treat "the required checks passed" as "the PR is done" if
Codecov is flagging new uncovered lines.

- **New code ships with tests that exercise it, in the same commit.** Don't
  add a function or a branch and leave it to be covered "later."
- Run `flutter test --coverage` yourself before opening a PR and spot-check
  `coverage/lcov.info` for the files you touched if you're not sure a new
  code path is actually hit (grep `SF:<path>` through to `end_of_record`,
  count `DA:` lines with a nonzero hit count).
- For code that only runs on one platform variant (an `_io.dart` file, a
  `dart.library.io` conditional export), remember `flutter test` runs on the
  Dart VM: it resolves conditional exports to the io side, and
  `defaultTargetPlatform` is forced to a fixed non-web value regardless of
  host OS. Import the concrete `_io.dart`/`_web.dart`/`_memory.dart` file
  directly in the test when you need to pin down which variant you're
  exercising, and use `debugDefaultTargetPlatformOverride` when a branch
  depends on `PlatformInfo`.
- A gap is acceptable only when it is genuinely not testable cheaply (e.g. a
  `Process.runSync` failure branch that would need mocking the process
  layer) — leave a short comment saying so rather than silently walking
  past it, and don't invent test infrastructure just to chase 100%.
- Prefer a real, deterministic integration-style test (temp dir + real file
  write, loopback `HttpServer`) over mocking when the thing under test is a
  thin wrapper around `dart:io` — that's usually less code than a mock and
  actually proves the behavior.

## dart:io stays behind the platform seam

`dart:io` may only be imported from `lib/core/platform/**`,
`lib/core/net/*_io.dart`, or `lib/features/**/data/**`.
`test/core/platform/no_dart_io_test.dart` enforces this by grepping `lib/`
and will fail your PR if you add a `dart:io` import anywhere else. If you
need platform-specific behavior somewhere else in the tree, add a seam
function to `lib/core/platform/` (conditional export pattern:
`export 'x_stub.dart' if (dart.library.io) 'x_io.dart';`) instead of
importing `dart:io` directly.

## Fixture-first for providers

Every source that fetches from a network API ships with a fixture captured
from a real response (`test/fixtures/`), not hand-written JSON. See
`CONTRIBUTING.md` and (once it lands) `docs/PROVIDERS.md`.

## Delivery cadence

Each plan phase (or sub-phase) lands as its own branch and PR, ends with a
`make check` pass and at least one `refuter` review, and gets tagged when it
represents a version milestone. Don't bundle unrelated phases into one PR.
