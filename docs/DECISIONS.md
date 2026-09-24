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
