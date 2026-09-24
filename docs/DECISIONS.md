# Decisions log

Dates below are when the decision was made or confirmed, not necessarily
when the underlying work shipped.

## 2026-09-23 — Sandbox off

macOS App Sandbox is disabled in both Debug and Release entitlements.
Personal app, never distributed via the App Store; the Flutter macOS
template's default sandbox blocks both outbound HTTP (`network.client`
absent) and reading `~/.config`, and this app needs both.

## 2026-09-23 — Plaintext config, mode 0600

Config lives at `~/.config/kurokan/config.json` in plaintext, not
Keychain / `flutter_secure_storage`. macOS Keychain needs entitlements and
a provisioning profile; Linux needs `libsecret` plus a running Secret
Service that a bare-WM CachyOS box may not have. A 0600 file next to
`~/.kube/config` matches the trust level already accepted on that machine.

## 2026-09-23 — Uptime Kuma via `/metrics`, not the status-page API

`GET /metrics` (Prometheus text format, HTTP Basic with an empty username
and the API key as password) covers every monitor including unpublished
ones, and gives response time / 24h uptime ratio / cert data in one call.
The drop-in alternative (`/api/status-page/{slug}` + heartbeat endpoint)
needs no auth but only sees monitors in public groups.

## 2026-09-23 — No Flutter plugins in v1

Window chrome, config path, "open folder", and version are all done with
native platform code / `dart:io` / `--dart-define` instead of plugins.
That is what keeps CocoaPods and `libsecret` off the toolchain requirements.

## 2026-09-23 — Real-world deviations from the plan's Uptime Kuma assumptions

The plan verified `/metrics` shape against Uptime Kuma 2.5.5 source. The
actual production instance runs 1.23.17 (confirmed via the `app_version`
metric) and its `/metrics` has neither a `monitor_id`
label nor any `monitor_uptime_ratio` family. Monitors are joined by the
full label set (name/type/url/hostname/port), not a numeric id, and
`uptime24h` stays null against this instance. See
`plans/2026-09-23-v1-implementation-plan.md` section 3a for the original
assumption and `lib/features/uptime/data/prometheus_text_parser.dart` for
the actual join logic.

## 2026-09-23 — Webdock API access pending account-owner grant; CPU unit (R1) unresolved

`API & Integrations` (needed to generate a `read:servers` token) is locked
behind account-owner permission on the Webdock account backing this app.
M3 shipped against the confirmed OpenAPI spec shape with synthetic
fixtures and one live-verified error path (401 with a placeholder token).
The CPU tile's unit (`resourceUsageStatus.cpu.used`/`allowed`, documented
only as "the metric's base unit") stays an open decision (R1 in the plan)
until a real sample confirms it.

## 2026-09-23 — App renamed to Kurokan (黒監)

"infra_monitor" → "Kurokan": package name, bundle id (`dev.haziq.kurokan`),
window/dock titles, config path (`~/.config/kurokan/config.json`, migrated
from the old path on the machine already running this app), the
`KUROKAN_CONFIG` override env var (renamed from `INFRA_MONITOR_CONFIG` for
consistency — this app has one user, so the breaking rename costs nothing),
and app icon (kanji-seal concept from `design/Icon.dc.html`, dark theme).
The GitHub repo name was initially left as `infra-monitor-dashboard`
(still an accurate description) but later renamed to `kurokan` on request,
to match the app name for profile pinning. GitHub redirects the old URL.

## Design deviations D1–D7

Full detail in `plans/2026-09-23-v1-implementation-plan.md` section 6,
"Deviations from the design, all content, none visual":

| # | What |
|---|---|
| D1 | Vitals KV rows show PROCS/SAMPLED, not UPTIME/LOAD (Webdock exposes neither) |
| D2 | CPU tile shows `percentUsed`, not a live vCPU count (Webdock gives a 30-min CPU-seconds window, not live load) |
| D3 | Setup screen shows one config path row for the current OS, not both macOS and Linux |
| D4 | Config shape is `webdock{slug,apiToken}` / `kuma{apiKey}`, not the design's `server{}` / `kuma{username,password}` |
| D5 | Network tile footer reads `· MTD`, not `· 30D` (Webdock's figure is month-to-date) |
| D6 | Monitor types are Kuma's raw `monitor_type` uppercased, not the design's `HTTPS`/`SMTP` |
| D7 | macOS traffic lights are the real native ones, not hollow monochrome circles |

## 2026-09-24 — dart:io seam (Phase 1.0)

All `dart:io` usage outside data sources now sits behind `lib/core/platform/`:
`ConfigStore` (io/memory), `environment`, `openFolder`, `configureNativeWindow`,
and a split `core/net/http_client.dart` (io/web). `ConfigLoader`/`ConfigWriter`/
`ConfigWatcher` became thin wrappers over a `ConfigStore`; their public API and
existing tests (including the 0600-permission test) are unchanged. A guard
test (`test/core/platform/no_dart_io_test.dart`) greps `lib/` and fails if
`dart:io` appears outside the seam, `core/net/*_io.dart`, or
`features/**/data/**`. Pure refactor: desktop behaviour is unchanged.

Scope trim vs. the plan's literal sketch: `core/net/platform_errors.dart`
(a `describeIoError` helper unifying `SocketException`/`TlsException`
handling) was skipped. `webdock_source.dart` and
`uptime_kuma_metrics_source.dart` still catch those dart:io exception types
directly, which the guard explicitly allows. This is fine for a `flutter
build web` JS (dart2js) target, since dart2js tolerates a `dart:io` import
and only throws at actual use. It is NOT fine for a `--wasm` target
(dart2wasm has no `dart:io` at all): the Phase 4 plan already avoids
`--wasm` for unrelated reasons (CanvasKit, no COOP/COEP on GitHub Pages), so
this isn't urgent, but if a wasm build is ever considered, build
`platform_errors.dart` and route these two sources through it first.

`PlatformInfo.isMacOS`/`isLinux` now use `defaultTargetPlatform` (Flutter,
web-safe) instead of `dart:io Platform.isMacOS`. Behaviourally identical on
real desktop builds. Side effect: `flutter_test` forces
`defaultTargetPlatform` to a non-macOS value by default, so widget tests on
a macOS dev machine now see `PlatformInfo.isMacOS == false` unless a test
explicitly sets `debugDefaultTargetPlatformOverride`. No current test
depended on the old value; a future test asserting macOS-only chrome needs
that override.

The memory-backed `ConfigStore` (web/demo, Phase 1.3+) keys its `_watchers`
map by the exact resolved file path. If a future demo/web config uses a
`KUROKAN_CONFIG`-style override with a non-default filename, a directory-only
`ConfigWatcher` (keyed via a synthetic `$dir/config.json`) will not see
writes to a different filename in that same directory. Not reachable today
(memory store isn't wired into the real app yet); revisit when Phase 1.3
wires up demo mode.

## 2026-09-24 — Config schema v2 + v1 migration (Phase 1.1)

`AppConfig`'s shape changed from two hardcoded sections (`webdock`, `kuma`)
to generic `SourceEntry{kind, id, provider, settings: Map<String,String>}`
lists (`hosts`, `uptime`, `containers`), validated against a `ConfigSchema`
interface (`lib/core/config/config_schema.dart`) passed into
`AppConfig.fromJson(json, {required schema})`. A v1 file (no `version` key,
has `webdock`+`kuma`) is migrated to v2 in memory only
(`lib/core/config/config_migration.dart`); never written back to disk by
the loader itself, since the config watcher would otherwise loop on its
own rewrite. The next Settings save persists v2 for real.

New validation rules, deliberately looser than v1: ids must be unique
across hosts+uptime+containers combined, and only "at least one source
overall" is required (previously both a webdock host AND a kuma uptime
source were mandatory). A config with only hosts, or only uptime, or only
containers, is now valid. One side effect: a hand-edited v1-shaped file
that drops its entire `kuma` section no longer fails as `isV1Config`
(needs both keys), so it skips migration and parses as a hosts-only v2
config instead of erroring `kuma section is required`. Not a corruption
risk, just a weaker error message for an edge case nobody hits via the
current settings form.

`lib/core/config/legacy_schema.dart` is a temporary `ConfigSchema`
hardcoding the two providers Kurokan supports today (webdock, kuma).
Phase 1.2's `ProviderRegistry` implements `ConfigSchema` for real (with a
`ProviderSpec` per provider) and replaces this file entirely.

`AppConfig` gained `firstHost`/`firstUptime` getters (first entry in
`hosts`/`uptime`, or null) as a compatibility shim so the current
single-source settings form and polling providers keep compiling without
being rewritten for N sources yet; deleted in Phase 3.1.
`vitals_provider.dart`/`monitors_provider.dart` use `config.firstHost!`/
`config.firstUptime!` (non-null assertions): the looser "at least one
source" rule above means a config with zero hosts (uptime-only) now loads
successfully but crashes these two providers with a null-check error
instead of a clean error state, since they still assume exactly one host
and one uptime source exist. This is real but consciously scoped out:
Phase 1.4 ("N-source polling") is what actually removes the
single-source assumption from these files; fixing it properly now would
mean building N-source polling early, out of order.

`ConfigSchema.providerIds(SourceKind)` lists every provider id a schema
recognizes for a given kind, used only so an "unknown provider" error can
name what's actually configured (`'hosts[0] has unknown provider "x"
(known: webdock)'`), per the plan's explicit requirement. Both
`legacy_schema.dart` and the test-side `testConfigSchema` implement it.

`SourceEntry.fromJson` coerces every field value to a `String` via
`.toString()` (so `"slug": 123` in a hand-edited file becomes `"123"`, not
a validation error) and keeps only the keys its schema's `FieldSpec` list
recognizes: any extra key a user adds to an entry by hand disappears the
next time Settings saves. Matches v1's existing looseness (it never
type-checked field values either), and is out of scope to tighten before
Phase 1.2 gives providers a real `FieldKind`-driven parser.

Found and fixed during review: the settings form's save path originally
constructed a brand-new `AppConfig` from only the two fields it edits,
silently dropping any second host/uptime entry, all containers, and the
entire `history`/`notifications`/`layout` sections back to their defaults
on every save. Fixed to carry everything the form doesn't edit through
from the loaded config (`lib/features/settings/settings_form.dart`);
covered by a regression test in `settings_form_test.dart`.

## 2026-09-24 — Provider registry (Phase 1.2)

`lib/core/config/legacy_schema.dart` is gone. `ProviderRegistry`
(`lib/core/providers/provider_registry.dart`) now `implements ConfigSchema`
for real, backed by a `ProviderSpec<S>` per provider
(`lib/core/providers/provider_spec.dart`: `id`, `tag`, `kind`, `fields`,
`create(SourceEntry, SourceDeps) -> S`, `label(SourceEntry) -> String`).
`webdockSpec`/`kumaSpec` live next to their existing source files
(`lib/features/vps/data/webdock_spec.dart`,
`lib/features/uptime/data/kuma_spec.dart`); `default_registry.dart` is the
one shared file that lists every provider Kurokan ships with.
`vitals_provider.dart`/`monitors_provider.dart` now build the real source
via `registry.hostSpec(...)!.create(entry, SourceDeps(...))` instead of
constructing `WebdockSource`/`UptimeKumaMetricsSource` directly; the `!`
there is safe on the app's actual load path (not the same risk as
`firstHost!`/`firstUptime!`), because `AppConfig.fromJson` already
validates `entry.provider` against `defaultRegistry` before the config
ever reaches this provider, and `providerRegistryProvider` is never
overridden away from `defaultRegistry`. The type system doesn't enforce
this pairing though: a test (or a future code path) that builds an
`AppConfig` directly, bypassing `fromJson`, with an unrecognized provider
would still hit a bare null-check crash here instead of a readable error.

Deviation from the plan's literal sketch: `defaultRegistry`'s pseudocode
in the plan already lists `demoHostSpec`/`demoUptimeSpec` alongside the
real providers, but those don't exist until Phase 1.3. This increment
ships `defaultRegistry` with only `webdockSpec`/`kumaSpec`; Phase 1.3 adds
the demo entries when the demo providers themselves land.

`ProviderRegistry.containers` is typed `List<ProviderSpec<Object?>>`
(always empty right now) since no `ContainerSource` domain interface
exists yet; Phase 2's Docker provider should introduce one and retype this
field properly instead of leaving it as `Object?`.

Table-driven guard per the plan ("every spec's `fields` keys equal exactly
what its `create` reads"), in `test/core/providers/provider_registry_test.dart`:
loops over every spec actually registered in `defaultRegistry` (so Phase
1.3's demo specs and Phase 2's real providers are covered automatically,
no new test needed per provider), builds a settings map from `spec.fields`
alone rather than a hand-typed literal, and asserts `spec.create(...)`
doesn't throw. Building settings from `fields` (not a literal someone
could keep in sync by hand and forget to) is what actually catches the
`settings['x']!` bug class: if `create()` reads a key with no matching
`FieldSpec`, that key is absent from the generated settings and the `!`
throws inside the test. A second test per spec parses the same generated
settings through `SourceEntry.fromJson(..., schema: defaultRegistry)`
first, proving the `FieldSpec` key names actually match what a real
`config.json` would use.

Found and fixed during review, twice. First: the settings form's save
path originally constructed a brand-new `AppConfig` from only the two
fields it edits, silently dropping any second host/uptime entry, all
containers, and the entire `history`/`notifications`/`layout` sections
back to their defaults on every save. Fixed to carry everything the form
doesn't edit through from the loaded config
(`lib/features/settings/settings_form.dart`); covered by a regression test
in `settings_form_test.dart`. Second: the table-driven guard above was
initially written as one hand-typed test per spec, comparing `fields` to
a literal key set and constructing from a literal settings map that
happened to already agree with both `fields` and `create()`. That proved
nothing beyond "the author remembered the same three facts twice" and
wouldn't have caught the exact bug it was meant to guard against (a
required field added to `create()` without a matching `FieldSpec` passes
`AppConfig.fromJson` silently, since `SourceEntry.fromJson` only copies
keys `fields` lists, then crashes at runtime in `vitals_provider.dart`/
`monitors_provider.dart`). Rewritten to generate settings from `fields`
itself, as described above.

## 2026-09-24 — Demo providers, demo mode, golden harness (Phase 1.3)

`demo` is now a real, registered provider (`lib/features/demo/demo_specs.dart`:
`demoHostSpec`, `demoUptimeSpec`, both with `fields: []`, no credentials
needed), added to `defaultRegistry` alongside `webdockSpec`/`kumaSpec`. This
completes what Phase 1.2 deliberately deferred (its own decision entry
above). `DemoHostSource`/`DemoMonitorSource`
(`lib/features/demo/demo_host_source.dart`, `demo_monitor_source.dart`) are
pure Dart (no `dart:io`, so they'll run in the Phase 4 web build) and
deterministic: every value is `base + amplitude * sin(tick / period) +
seeded noise`, where `tick` is elapsed seconds since a fixed anchor date
computed from an injected `Clock`, never wall-clock `DateTime.now()`
directly. `DemoScenario.incident` pins the CPU gauge to 97% (crit) and the
first monitor to DOWN **unconditionally** (not only "at tick 0" as the
plan's phrasing suggested) so a screenshot at any fixed clock value
reliably shows the same bad state; `DemoScenario.calm` (production demo
mode's default) never reaches crit or DOWN.

The setup screen's "Try with demo data" button
(`lib/features/setup/setup_screen.dart`) just writes `demoConfig()`
through the normal `ConfigWriter`, the same as any real Settings save. It
loads back through the exact same registry-driven path as a real config;
"demo" isn't a special code path anywhere in the loading/polling
pipeline, only a provider id. Separately, `--dart-define=KUROKAN_DEMO=true`
(`PlatformInfo.isDemo`, already built in Phase 1.0, not duplicated here as
the plan's sketched `lib/core/config/demo_mode.dart`/`kDemoMode`) makes
`AppRoot` skip disk I/O entirely and use `demoConfig()` in memory. Opening
Settings while in this mode still writes a real file (nothing currently
guards against that), but nothing reads it back, since the watcher and
`_tryLoad()` never start in that branch.

`backfill(ticks, step)` (seeding history from a demo source) is not
implemented: the plan itself says this feeds Phase 3.2's history store,
which doesn't exist yet. Building it now would be an abstraction with no
consumer.

Found and fixed during review: the "Try with demo data" button originally
showed whenever `SetupScreen` renders at all, including the
`isInvalid` (invalid, not just missing, config) state. A file with a typo
can still hold real Webdock/Kuma credentials; clicking the button there
silently overwrote it with no confirmation. Fixed by only showing the
button when `error == null || error!.notFound`
(`lib/features/setup/setup_screen.dart`), covered by two tests. Writing
the invalid-config test surfaced a second, unrelated pre-existing bug in
the same file: the footer row's "INVALID CONFIG · WATCHING FOR FILE" text
overflowed its `Row` by a few pixels (never caught before since nothing
had ever rendered `SetupScreen` in that specific error state); fixed by
wrapping it in `Expanded` with `TextOverflow.ellipsis`.

Golden images must be generated on Linux, not macOS: `refuter` caught that
the ones first committed here were generated locally on macOS arm64, and
at the comparator's 0.1% tolerance a text-heavy 1100x720 frame will not
match Linux's different text rasterization (the whole reason the plan
puts goldens on Linux-only in the first place). Regenerated via
`docker run --platform linux/amd64 ghcr.io/cirruslabs/flutter:<version>
flutter test -t golden --update-goldens` before committing.

Known cosmetic gap, not fixed here: the vitals panel's tag still reads
"WEBDOCK" even when the active source is `demo` (see the golden
screenshots). Panel tags become provider-driven (via
`ProviderSpec.tag`, already added in Phase 1.2) only once Phase 1.4/1.5's
panel registry replaces the current hardcoded panel wiring.

**Golden harness.** `test/goldens/flutter_test_config.dart` (deliberately
placed inside `test/goldens/`, not at the `test/` root) loads every
pubspec font via `FontLoader` and installs a `TolerantGoldenComparator`
(accepts up to 0.1% pixel diff) plus `debugDisableShadows = true`. Two
non-obvious things that cost debugging time:

- `FontManifest.json` percent-encodes special characters in asset paths
  (`Fraunces[SOFT,WONK,opsz,wght].ttf` becomes `...%5BSOFT...%5D.ttf` in
  the manifest), but `rootBundle.load()` needs the raw, decoded key.
  Without `Uri.decodeFull(...)`, every font fails to load with "asset does
  not exist."
- **`flutter_test_config.dart` must not live at the `test/` root.** Flutter
  applies it to every test file found at or below its location by walking
  up the directory tree from each test file. Placed at `test/`, it
  originally wrapped the *entire suite* in
  `TestWidgetsFlutterBinding.ensureInitialized()`, which silently broke
  `test/core/net/http_client_io_test.dart` (a real loopback `HttpServer`
  test): Flutter's test binding blocks all real HTTP requests once
  initialized ("all HTTP requests will return status code 400"). Scoping
  the config file to `test/goldens/` fixes this; only golden tests pay for
  font loading and the tolerant comparator.

`lib/features/setup/setup_screen.dart` had zero test coverage before this
phase; the new `test/features/setup/setup_screen_test.dart` covers only
the new "Try with demo data" button. The pre-existing "Set up now"
navigation and the invalid-config error-display branch remain untested,
same call as everywhere else in this log: fix what the diff touches, not
unrelated gaps in the same file.

`test/goldens/dashboard_golden_test.dart` renders the dashboard at
1100x720 @1x, dark and light, with a `Clock.fixed(...)` passed both
directly to the demo sources and via `withClock(...)` around the pump
(since `lib/core/polling/polled.dart`'s `Sample.fetchedAt` reads the
*ambient* `clock.now()`, not an injected one, so the "last refreshed"
timestamp needs the same fixed clock to stay deterministic). Tagged
`@Tags(['golden'])`, declared in the new `dart_test.yaml`. Golden platform
is Linux only (macOS text rasterization differs): the Makefile `test`
target already excluded goldens since Phase 1.0 (`-x golden`, added ahead
of this phase); `.github/workflows/ci.yml`'s `check` job now has a
dedicated `flutter test -t golden` step so CI is the only place they
actually run.
