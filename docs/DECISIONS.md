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

## 2026-09-24 — Polling for N sources + panel registry (Phase 1.4)

`vitals_source.dart` is gone; `HostsSource` (`lib/features/vps/domain/hosts_source.dart`)
replaces it with `Future<List<HostVitals>> fetch()` instead of a single
`HostVitals`. `WebdockSource`/`DemoHostSource` now wrap their one host in a
list. Nothing today yields more than one, but the interface has to allow
it before a Phase 2 provider (e.g. a fleet-wide Prometheus exporter) can
return several without another interface break.

`lib/core/polling/polled.dart` gained `polledFamily<T, A>`, the
`FutureProvider.family` counterpart of the existing `polled<T>`. Same
shape (`interval`/`fetch` callbacks, a `Timer` per instance re-invalidating
itself, `retry: (_, _) => null` since the timer alone owns cadence), but
keyed per argument so each configured source gets its own independent
poll loop and its own stale/error state. `FutureProviderFamily` has to be
imported from `package:flutter_riverpod/misc.dart`, not the main barrel.

`vitals_provider.dart`/`monitors_provider.dart` are gone, replaced by
`hosts_provider.dart`/`uptime_provider.dart`: a `Provider.family<S,
String>` that resolves one config entry by id and builds its source via
the registry, feeding a `polledFamily`. This is also what resolves the
`firstHost!`/`firstUptime!` crash risk flagged in Phase 1.1's log entry:
that risk was specifically "a config with zero hosts (uptime-only) crashes
the vitals provider with a null-check error," and the new
`panelRegistryProvider` (below) only ever calls `hostsProvider(id)` for an
`id` it read off `config.hosts` itself, so a hosts-empty config simply
produces zero host panels instead of constructing a provider that has
nothing to point at. `settings_form.dart` still reads `firstHost`/
`firstUptime` (with `?`, never `!`), untouched here; it stays a
single-source form until Phase 3.1.

`lib/features/dashboard/panel_registry.dart` is new: `PanelEntry{key,
sourceId, slot, fetchedAt, isLoading, hasError, build}` and
`panelRegistryProvider`, which watches every configured uptime/host source
and emits one `PanelEntry` per source, sorted by `config.layout.order`
(entries not named in `order` keep their config-declared relative order,
appended after the ones that are named). `marginMetaProvider` moved the
`dashboard_screen.dart` margin-text logic here too: a single configured
host shows its own registry label, more than one falls back to a
`"$N HOSTS · $M UPTIME"` summary, since there's no longer one canonical
host to name.

`dashboard_screen.dart`'s two panel slots each render a `_PanelColumn`
that stacks every `PanelEntry` in that slot, with a fixed-height `SizedBox`
gap (not a visible divider line) between them, when a config has more than
one source of a kind. This is Phase 1.4
scope only (make it not break); the actual responsive multi-panel layout
(breakpoints, collapsing to a single column) is Phase 1.5's job, noted
in-code.

`shared/widgets/source_error_text.dart` is new: `sourceErrorKind`/
`sourceErrorMessage` extracted from what used to be near-duplicate private
functions inside `vitals_panel.dart` and `monitor_panel.dart`. The old
per-panel messages hardcoded the provider name in the string ("CHECK
webdock.slug", "FROM WEBDOCK"); with N possible providers behind one
panel, that's wrong for every provider but one, so the shared version
takes the active source's tag as a parameter instead. This also fixes the
cosmetic gap Phase 1.3 documented (`VitalsPanel`'s tag read "WEBDOCK"
even in demo mode): both panels now resolve their tag from
`registry.hostSpec(entry.provider)?.tag`/`uptimeSpec(...)?.tag`, falling
back to `entry.provider.toUpperCase()` only if the registry somehow has no
spec for it (not reachable via `AppConfig.fromJson`'s own validation, same
caveat as Phase 1.2's registry `!` note).

`VitalsPanel` renders `hosts.first` and treats an empty list as a
`_EmptyHostsBody` rather than crashing on `.first`: every provider today
(webdock, demo) always yields exactly one host, so this branch isn't
reachable in practice yet. Phase 1.5 adds the compact multi-host table
Phase 2's fleet-wide providers will actually need; building it now would
be speculative.

Deviation from the plan's literal file list: the plan named
`config_watcher.dart` for the "ignore unrelated file writes in the config
directory" fix, but that file doesn't exist here; the real
`Directory.watch()` logic is in `lib/core/platform/config_store_io.dart`'s
`changes()`, which is what changed instead. It now compares each
`FileSystemEvent`'s basename against the store's own resolved filename
(and its `.tmp` sibling) and drops anything else, so an editor swap file,
`.DS_Store`, or a future Phase 3 history JSONL sitting in the same
directory can no longer trigger a spurious reload.

Coverage gaps caught after the initial implementation, all closed before
this phase's PR: `test/features/dashboard/panel_registry_test.dart` is new
(the plan's own explicit requirement — asserts a migrated v1 config yields
exactly `[uptime:kuma wide, host:webdock narrow]` — plus a `layout.order`
reordering case and both `marginMetaProvider` branches).
`config_store_io_test.dart` gained a case proving a stray file write in
the config directory does not fire `changes()` while the config file (or
its `.tmp`) still does. `source_error_text.dart`'s two functions had zero
direct test coverage despite being new and shared by both panels; added
`test/shared/widgets/source_error_text_test.dart` covering every
`FetchError` variant. Neither panel's "fails on the very first fetch"
branch (`hasError && !hasValue`, the `ErrBlock`/tag-fallback path) had ever
been exercised by any test at any level; added one case per panel to
`dashboard_screen_test.dart`, plus a two-host case covering
`_PanelColumn`'s multi-panel branch. Left uncovered, and not new to this
phase: `vitals_panel.dart`'s "stopped"/"suspended" status-glyph branch and
`dashboard_screen.dart`'s settings-navigation callback, both pre-existing
gaps untouched by this diff.

Codecov's patch-coverage comment on the PR caught 7 lines this initial
pass missed, all inside code this phase actually added: the `?? entry.
provider.toUpperCase()` tag-fallback in both `vitals_panel.dart` and
`monitor_panel.dart`, `vitals_panel.dart`'s own stale-after-one-good-fetch
footer (the existing stale-footer test only ever failed the *monitors*
side, never the *vitals* side), and `_EmptyHostsBody`. The last of these
had been dismissed above as "not reachable by any current provider," which
is true of the real webdock/demo sources but wrong as a reason to skip
testing it: a fake `HostsSource` returning `[]` (the same kind of test
double already used throughout this file) reaches it in one line, no new
test infrastructure needed. Likewise the tag-fallback branch is reachable
by pointing a `SourceEntry.provider` at an id the registry doesn't
recognize while overriding the source provider directly (bypassing the
separate, legitimately-unreachable `!` in `hosts_provider.dart`/
`uptime_provider.dart` that assumes `AppConfig.fromJson` already
validated the id). Four more cases added to `dashboard_screen_test.dart`
close all 7; the only remaining gap in these two files is the pre-existing
"stopped"/"suspended" branch noted above.

Found and fixed during `refuter` review: `config_store_io.dart`'s new
basename filter (above) only checked `event.path`, which is correct for
the app's own atomic write (`config.json.tmp` renamed onto `config.json`,
reported as name-matching events on both macOS FSEvents and Linux
inotify) but silently dropped an *external* atomic write, e.g. `jq ... >
.swp && mv .swp config.json`, a JetBrains "safe write", or vim's default
`backupcopy=no`. On Linux, inotify reports that rename as a single
`FileSystemMoveEvent` whose `path` is the old temp name and whose
`destination` is `config.json`; the filter saw a non-matching `path` and
dropped it before ever looking at `destination`. Before this phase, any
event in the directory triggered a reload, so this was a real regression
on a target platform, not just a missed test case. Fixed by also matching
`FileSystemMoveEvent.destination`'s basename; covered by a new
`config_store_io_test.dart` case that renames an arbitrarily-named temp
file onto the config path (passes on macOS via the pre-existing
Delete+Create path, and is the case that actually exercises the new
branch on Linux CI). Also caught and fixed in the same pass:
`panel_registry.dart` was hand-building `'uptime:${id}'`/`'host:${id}'`
instead of reusing `SourceEntry.panelKey` (`config_schema.dart`), which
would have been a second definition to keep in sync by hand; a couple of
new tests were shallower than their descriptions claimed (the two-host
stacking test used identical fake data on both hosts, so it couldn't have
caught the second panel being wired to the wrong source; the uptime
first-fetch-error assertion stopped short of the provider tag it claimed
to check; the `polledFamily` "independent interval" test gave both args
the same 30s interval, so a shared timer would have passed too) — all
three tightened to actually verify what their names say.

Golden images regenerated (same Linux-only technique as Phase 1.3: a
temporary push-triggered workflow running `flutter test -t golden
--update-goldens` on `ubuntu-24.04`, PNGs pulled via `gh run download`,
workflow file deleted before merge). This is a deliberate pixel change,
not a regression: the Vitals panel's tag in `dashboard_light.png`/
`dashboard_dark.png` now reads "DEMO" instead of the old hardcoded
"WEBDOCK", closing the cosmetic gap Phase 1.3 documented.

## 2026-09-24 — Dashboard layout from config (Phase 1.5)

`lib/features/dashboard/dashboard_layout.dart` is new: a pure
`LayoutPlan planLayout(List<PanelEntry> panels, double width)` returning
either `TwoColumn{wide, narrow}` (>= 900px, today's 62/38 flex + 40px gap)
or `SingleColumn{panels}` (below it, every panel stacked in one scrollable
column). Named `planLayout` rather than the plan doc's literal `plan`: a
bare `plan` as both the top-level function and the natural name for
`PanelGrid`'s own constructor parameter reads confusingly at the call site
(`PanelGrid(plan: plan(panels, width))`), so the function got the more
specific name instead.

`lib/features/dashboard/panel_grid.dart` is new: `PanelGrid` renders
whichever `LayoutPlan` it's given, replacing `dashboard_screen.dart`'s
hardcoded `Row` (the actual two/single-column decision now lives in
`dashboard_layout.dart`, not in the screen widget). The `_PanelColumn`
helper that stacks multiple panels within one slot (added in Phase 1.4)
moved here unchanged. Single-column cells are wrapped in a fixed
`SizedBox(height: 420)`: a bare `ListView` child gets unbounded height,
and `VitalsPanel`'s body puts a `GridView` inside an `Expanded`, which
needs a finite constraint from somewhere above it.

A host source that yields more than one host (a fleet-wide Prometheus
exporter, Phase 2) now renders `HostTablePanel`
(`lib/features/vps/presentation/host_table_panel.dart`) instead of
`VitalsPanel` exploding into one detail tile per host:
`VitalsPanel.build()`'s body is now a three-way `switch` on `hosts.length`
(0 -> `_EmptyHostsBody`, 1 -> today's `_VitalsBody`, N -> `HostTablePanel`,
a row per host with glyph/name/CPU%/MEM%/DISK%). Deviation from the plan's
row shape: no "load" column. The plan assumed `HostVitals` would already
carry a load figure by the time this phase landed, but that field is
Phase 2.0's `extra: Map<String,String>?` addition, which hasn't shipped
yet; adding a load column now would mean inventing a field a phase early.
`_statusGlyphFor` (private, duplicated nowhere else before this phase)
moved out of `vitals_panel.dart` into a shared
`lib/features/vps/presentation/host_status_glyph.dart` (`hostStatusGlyph`)
since both the detail view and the new table need the exact same
`HostVitals.status` vocabulary; this is the same domain type used twice,
not two coincidentally-similar switches (unlike `monitor_row.dart`'s own
independent glyph mapping for a different domain, which stays as its own
small duplicate per existing convention).

No current provider (webdock, demo) ever yields more than one host, so
`HostTablePanel` has no live path to exercise outside a test that injects
a fake `HostsSource` returning 2+ `HostVitals` — added to
`dashboard_screen_test.dart`, plus a dedicated
`host_table_panel_test.dart` for the row/column rendering itself and
`host_status_glyph_test.dart` for the glyph mapping now that it is a
standalone shared function. `dashboard_layout_test.dart` covers
`planLayout` directly (breakpoint boundary, empty panel list, multiple
panels per slot) per the plan's "pure plan cases" requirement, and a new
`dashboard_screen_test.dart` case pumps the full dashboard at 800px
(below the 900px breakpoint) and asserts the uptime panel's top-left `dy`
is above the vitals panel's, per the plan's explicit "widget test at
800px" requirement.

`config.example.json` and `docs/config.schema.json` were already
rewritten to schema v2 in an earlier phase (Phase 1.1); the plan's mention
of rewriting them here was stale by the time this phase landed, so
nothing changed in either file.

Verified no golden regeneration was needed: the 1100x720 golden harness
renders well above the 900px breakpoint, so `TwoColumn` (identical 62/38
flex + 40px gap to the pre-Phase-1.5 hardcoded `Row`) is still what
renders. Confirmed by diffing the local macOS pixel-mismatch percentage
against unmodified `main` before committing (both `2.22%`/`2.20%`,
identical): the usual macOS-vs-Linux text-rasterization gap this repo has
always had locally, not a change from this phase.

## 2026-09-24 — Shared model extensions (Phase 2.0)

Foundation for Phase 2's providers, unblocking nothing visible on its own:
`lib/features/vps/domain/host_vitals.dart`'s `Gauge.allowed`/`percentUsed`
are now `double?`, and `HostVitals.memory`/`disk`/`network` are now
`Gauge?` (`cpu` stays required and non-null: every provider so far can
report CPU, so there's no case to design for yet where it can't).
`HostVitals` and `MonitorStatus`
(`lib/features/uptime/domain/monitor_status.dart`) both gained an
`extra: Map<String,String>?` for provider-specific extras that don't fit
today's typed fields (load, uptime, kubelet version, Prometheus's 30d/365d
windows); nothing populates it yet, that's Phase 2.1+'s job.

New `Gauge.fromUsedAllowed(used, allowed, {unit, warnAt = 80, critAt =
95})`: for a provider that only reports raw used/allowed and leaves us to
derive percent/level ourselves (Webdock computes both server-side and
keeps using the plain `Gauge(...)` constructor directly; Prometheus
node_exporter and Docker stats, Phase 2.2/2.3, don't). A null, zero, or
NaN `allowed`, or a NaN `used`, yields `percentUsed: null` and
`level: ok` rather than a divide-by-zero or a NaN leaking into the UI.
`demo_host_source.dart`'s own private `_gauge()` helper was an
near-exact duplicate of this exact logic (level-from-percent with
per-kind `warnAt`/`critAt` overrides); refactored to call the new factory
instead of keeping two copies, which also serves as the first real proof
the factory behaves identically to what it replaces (same test file,
unchanged assertions, still green).

`StatTile.unavailable({label, sub = '—'})` renders `—` for a gauge a
provider genuinely can't supply. `vitals_panel.dart`'s three percent
tiles (CPU/Mem/Disk) now go through a shared `_percentTile` helper that
falls back to `.unavailable` when the gauge itself is null OR its
`percentUsed` is null; `host_table_panel.dart`'s CPU/MEM/DISK columns
have the same fallback via a small `_percentText(double?)` helper.
Network keeps its own separate fallback (`_networkTile`) rather than
sharing `_percentTile`, since it displays a scaled absolute used/allowed
pair, not a percent, and needs `allowed` specifically (not just
`percentUsed`) to render at all.

Deliberately deferred, not designed here: a gauge with a real `used` but
no `allowed` (genuinely uncapped, e.g. an unmetered network interface) is
treated identically to an absent gauge, falling back to `.unavailable`
rather than a dedicated "used, no cap" display. No current or Phase 2
provider actually reports one; building that display now would be
speculative UI for a shape of data nothing produces yet.

Coverage note: Dart's coverage is line-based, not branch-based, so a
single-line ternary (`host_table_panel.dart`'s `_percentText`) shows as
"covered" once either branch executes even once. `host_table_panel_test.dart`
already had fixtures for the non-null path from Phase 1.5; a genuinely
null-gauge fixture was added here so the `—` fallback is actually
exercised, not just line-covered by coincidence. Also caught this way:
`_networkTile`'s own null-gauge branch is a `const` expression, which the
VM never instruments at all (no DA: entry, not even a "0 hits" one) — it
would have been invisible to a coverage-gap sweep even though it was
genuinely untested; a dashboard-level widget test with a host missing
memory/disk/network now exercises it directly instead of relying on lcov
to notice.

Found and fixed during `refuter` review: that same dashboard-level test's
original assertion, `expect(find.text('—'), findsWidgets)`, was itself a
false positive. `StatTile`'s big number is a `RichText`, not a `Text`, and
`find.text()` only matches `RichText` with `findRichText: true` (default
`false`); the assertion was passing only because the unrelated `Procs`
`KvRow` (`processCount: null`) already renders a plain-`Text` `—`. It
proved "no crash", not "the fallback tiles actually show `—`". Fixed by
adding `findRichText: true` and asserting an exact count (7: three
unavailable tiles x number+sub, plus the `Procs` row), after giving the
test's `MonitorStatus` fixture a real `responseTime`/`uptime24h` so the
Monitors panel's own unrelated `—` cells (`RESP`/`24H` on a bare status)
don't pollute that count.

Left uncovered, pre-existing, not touched by this diff: `stat_tile.dart`'s
`warn`-level border decoration (no test constructs a `StatTile` with
`level: UsageLevel.warn` specifically) and the gaps already logged in
Phase 1.4/1.5 (`vitals_panel.dart`'s "stopped"/"suspended" status glyph,
`dashboard_screen.dart`'s settings-navigation callback).

## 2026-09-25 — Uptime Kuma version-adaptive parsing (Phase 2.1)

`lib/features/uptime/data/prometheus_text_parser.dart`'s `parse()` now
returns `ParseResult{monitors, hasIds, hasUptime}` instead of a bare
`List<MonitorStatus>`: `hasIds` is true if any monitor line carried a
`monitor_id` label, `hasUptime` if any `monitor_uptime_ratio` line was
present at all (any window). Neither flag is wired into any UI yet; this
phase is scoped to the parser and its data, per the plan. The real
1.23.17 fixture (`test/fixtures/uptime_kuma_metrics.txt`) has neither, and
now has a test asserting exactly that:
`app_version{version="1.23.17"...}` in that fixture is the plan's basis
for "the 24H column shows `—` honestly on 1.23" (the data genuinely isn't
there, not a parsing bug). `uptime_kuma_metrics_source.dart`'s `fetch()`
unwraps `.monitors` since `MonitorSource.fetch()` still returns
`List<MonitorStatus>`.

Grouping now prefers `labels['monitor_id']` over the existing full-label-
set composite key when a `monitor_id` is present (older Kuma, 1.23.x,
never emits one; the composite-key fallback is what the "against the real
captured fixture" test group already covered). The last `monitor_status`
line seen for a given key now sets that monitor's displayed `name`/`type`,
instead of the accumulator's name/type being fixed once at first creation
from whatever line happened to appear first.

Found and corrected during `refuter` review: this was first written up as
"whichever series carries `monitor_status` is authoritative for identity"
(picking the live series over a rename's stale orphan), but that framing
doesn't hold up. A real orphan series still emits its own `monitor_status`
line (it's not a series that's missing that metric, just a series that's
stale) — so both the live and orphan series compete on this field exactly
like every other field already does, and the actual mechanism is "the
last line in the body wins," full stop, no different from how
`monitor_response_time` already behaved. The corrected comment and test
(`prometheus_text_parser_test.dart`, "when a rename leaves two
monitor_status lines sharing the same id...") describe this honestly:
whichever series Prometheus's exporter happens to list last in the body
wins the name shown, which is *probably* the live one in practice (an
actively-reporting monitor likely still gets a fresh line each scrape,
while an orphan may drop off first), but nothing in the parser itself
knows or guarantees that.

`double.tryParse('NaN')` returns `double.nan` in Dart, not `null` — the
existing `if (value == null) continue` guard let a literal `NaN` metric
value flow straight into `Duration(milliseconds: value.round())`
(`.round()` on NaN throws `UnsupportedError`) or a stored NaN percent.
Fixed with an explicit `|| value.isNaN` on the same guard.

`monitor_uptime_ratio`'s 30d/365d windows, previously silently discarded
(only `window == '1d'` was ever stored anywhere), now land in
`MonitorStatus.extra` as `'uptime_30d'`/`'uptime_365d'` string keys — the
first real consumer of the `extra` map Phase 2.0 added. Nothing reads
them yet (no UI change); Phase 3's history/sparkline work is the more
likely place to actually surface them, not this phase.

Found and fixed during `refuter` review: `hasUptime` was originally set
inside the `monitor_uptime_ratio` switch case, which only runs after the
NaN/null value guard — so a response where every uptime ratio happened to
be `NaN` would report `hasUptime: false`, indistinguishable from "this
Kuma version doesn't emit uptime ratios at all," which is exactly the
distinction this flag exists to make. Fixed by setting `hasUptime = true`
as soon as the metric name is recognized, before the value is parsed or
validated at all; a dedicated test (`prometheus_text_parser_test.dart`,
"hasUptime is true even when every monitor_uptime_ratio value is NaN")
covers it.

`monitor_response_time_seconds` needs no special-case skip: it was
already ignored structurally (the metric-name `switch` only matches
`'monitor_response_time'` exactly, and Dart's `switch` does nothing for
an unmatched value), so this phase only adds a test proving that's true
and a code comment saying so, not new logic. Tag labels
(`tag_slug` in the new fixture) were already excluded from both the
existing composite key and the new `monitor_id`-based key, needing no
change either — same story, a test now proves it rather than the
guarantee resting on the label simply never being referenced anywhere.

New fixture `test/fixtures/uptime_kuma_metrics_v2.txt`: two monitors, one
with `monitor_id`, three uptime windows, a `tag_slug` label, a `NaN`
response time, and a bare `monitor_response_time_seconds` line — a
synthetic composite of every Phase 2.1 behavior in one file, distinct
from the real single-purpose `uptime_kuma_metrics.txt` capture. Live-
verification against a real newer Kuma instance (the plan's own
suggestion) wasn't done here: Haziq's own reachable instance is the
1.23.17 one already captured, which predates all of these fields.

Found and fixed during `refuter` review: two tests were weaker than their
names claimed. The v2 fixture's own test only checked `hasIds`/`hasUptime`
and that the monitor list was non-empty with non-empty ids — it never
checked a single actual field value, so it would have passed even if the
parser silently dropped every gauge. Rewritten to assert both monitors'
full fields (name, type, state, response time, uptime, cert, `extra`)
against hand-traced expected values. Separately, "a tag label does not
affect grouping" put the *same* `tag_slug` value on both of a monitor's
lines, so it would still have passed even if tags were part of the
grouping key (as long as both lines had the same tag). Rewritten to put
the tag on only one line, with a variant covering both the composite-key
and `monitor_id`-keyed paths.

Left uncovered, pre-existing, not touched by this diff:
`uptime_kuma_metrics_source.dart`'s `HttpException` catch branch and
`prometheus_text_parser.dart`'s `_unescape`'s `\n`/default-escape
branches (neither function was touched by this diff).

## 2026-09-25 — Docker/Podman containers (Phase 2.2)

The headline panel: a new `lib/features/containers/` feature dir
(`domain/container_status.dart`: `ContainerState`, `HealthState`,
`ContainerStatus`, `ContainerSource`), a Docker Engine API source, and a
`ContainersPanel` (narrow slot). `SourceKind.containers`,
`AppConfig.containers`, and `ProviderRegistry.containers` already existed
(Phase 1.1/1.2, typed `List<ProviderSpec<Object?>>` as a placeholder); this
phase is what actually fills them in, retyped to
`List<ProviderSpec<ContainerSource>>` now that the interface exists.

**Live-verified against a real OrbStack Docker daemon** on this machine
throughout this phase, not just against captured fixtures: started real
containers in three states (a healthy one with a configured healthcheck,
a plain one with none, one that exits immediately), captured `/version`,
`/info`, `/containers/json`, per-container `/containers/{id}/json` and
`/containers/{id}/stats?stream=false` from the actual API, then ran the
finished `DockerSource.fetch()` directly against the live socket
end-to-end (a throwaway script, deleted after) and confirmed sane
CPU%/mem/health/state output before tearing the containers down. The
fixtures under `test/fixtures/docker/` are trimmed captures of that real
traffic (container names changed to something demo-appropriate).
`test/fixtures/docker/stats_podman_zero_precpu.json` is fully synthesized,
since this machine has no Podman to capture from. `stats.json`'s CPU
counters are also hand-adjusted, not a pure capture: the real container
was idle (0% CPU) at capture time, which doesn't exercise the percent
math in a test meaningfully, so `total_usage` was nudged up to produce a
realistic ~20% reading. `refuter` review caught that this nudge, done
during the initial pass, left `usage_in_kernelmode`/`usage_in_usermode`
unadjusted, so they no longer sum to the (bumped) `total_usage` — a real
cgroup read can't do that. `DockerStatsDTO` never reads those two fields,
so it had no effect on any test's correctness, but it made the fixture
look less like a real capture than it should; fixed by bumping
`usage_in_usermode` by the same amount as `total_usage`.

**Transport** (`lib/core/net/docker_client_io.dart`, inside the Phase 1.0
`dart:io` allowlist as a `core/net/*_io.dart` file): `DockerEndpoint` is
`UnixSocket(path)` or `Tcp(host, port, {certPath})`. Deviation from a
literal reading of `DockerSource`'s own constructor (`{client, apiVersion,
stats, concurrency}`, no endpoint parameter): since `DockerSource` never
sees the endpoint, `dockerHttpClient(endpoint)` has to redirect *every*
connection to it via `HttpClient.connectionFactory`, for `Tcp` as much as
`UnixSocket` — not just the unix-socket case the plan's own code sketch
implied — so `DockerSource` can always address requests to a placeholder
`http://localhost/...` URI regardless of which transport it's actually
talking over. `io.findProxy = (_) => 'DIRECT'` is required alongside the
factory (confirmed straight from the `dart:io` SDK source's own doc
example for this exact unix-socket-Docker use case, `_http/http.dart`):
without it, connections may otherwise get funneled through a system HTTP
proxy meant for real network traffic, which will not work for either
transport here. TLS for `Tcp` (`DOCKER_CERT_PATH`/`SecurityContext`) is
the plan's own stated follow-up "if time allows" — not implemented;
`certPath` is accepted and stored but unused. Both endpoint variants are
genuinely live-tested: `UnixSocket` against the real OrbStack socket,
`Tcp` against a loopback `HttpServer` proving the connection redirect
(not just that a plain TCP client can be built).

**Endpoint discovery** (`lib/features/containers/data/
docker_endpoint_discovery.dart`): the `endpoint` settings field (default
`'auto'`) resolves through `DOCKER_HOST`, then the documented candidate
socket paths in order, falling back to `/var/run/docker.sock` even when
nothing was found (so the resulting error is "connection refused at
/var/run/docker.sock", not a dead end). The candidate filesystem check
(`File.existsSync`) is injectable (`exists` parameter, defaulting to the
real one) purely so tests don't depend on what sockets happen to exist on
whatever machine runs them — this machine has a real OrbStack socket at
the default path, which would otherwise make a broken "no candidate
found" fallback path look like it passed for the wrong reason. The
`/run/user/$UID/podman/podman.sock` candidate depends on a `UID`
environment variable that, confirmed during `refuter` review, isn't just
"some shells don't export it" — it's empty in `printenv` under both zsh
and bash on this machine, and a GUI-launched app has no shell to inherit
it from regardless, so this candidate is effectively dead in real use.
Added `$XDG_RUNTIME_DIR/podman/podman.sock` ahead of it in the candidate
list: rootless Podman's systemd user session actually exports
`XDG_RUNTIME_DIR` by default, so that candidate has a real chance of
matching where the `$UID` one doesn't. The `$UID` candidate is kept
anyway for a shell session that happens to export it; an explicit
`endpoint` setting or `DOCKER_HOST` remains the fully reliable path
either way.

**DockerSource** (`lib/features/containers/data/docker_source.dart`):
`/_ping` and `/info` first, as connectivity/sanity checks (matching
`WebdockSource`'s error-mapping template: `NetworkError`/`AuthError`/
`HttpError`/`ParseError`/`TimeoutError`), then `/containers/json?all=1`,
then per-container `/containers/{id}/json` + `/containers/{id}/stats?
stream=false` through a small hand-rolled bounded-concurrency worker pool
(`concurrency` workers pulling the next index off a shared counter; no
dependency needed for this). Two deviations from the plan's literal
endpoint list, both because `ContainerSource.fetch()` (the plan's own
interface) returns only `List<ContainerStatus>`, with nowhere to put
host-level data: `/info`'s `Name`/`NCPU`/`MemTotal`/`ContainersRunning`
are fetched (as the sanity check above) but never surfaced anywhere —
the panel's footer ("N RUNNING · M EXITED") is instead computed
client-side from the fetched list itself, which the plan's own
`ContainersPanel` section describes doing anyway. `/version` is skipped
entirely: `/info`'s own `ServerVersion` field already covers what it
would add, confirmed against the real captured `/info` response, so
calling it would just be a second request for data with nowhere to go.

Per-container inspect/stats calls each get their own 3s timeout and
degrade to defaults (health `none`, restart count 0, every gauge/
`startedAt` null) rather than failing the whole panel — this is the same
"one straggler shouldn't take down the group" principle Phase 2.1's
uptime parsing and Phase 1.4's polling already apply, just at the level
of one container within one source's fetch instead of one source within
the dashboard. Two things `refuter` review surfaced here, both accepted
rather than fixed:
- A degraded container's `restartCount: 0`/`health: none` is
  indistinguishable from a container that's genuinely healthy with zero
  restarts; the only visible tell is its uptime column reading `—` even
  though the container is running. Fixing this would mean adding a
  tri-state ("unknown" vs "zero") to `ContainerStatus`, which the plan's
  own literal field shapes (`final int restartCount`, non-nullable) don't
  have room for; not changed here.
- `.timeout()` on the per-container calls doesn't cancel the underlying
  request — `package:http`'s `Client` has no cancellation token, so a
  request against a hung daemon keeps running in the background past the
  3s the caller stops waiting for it. This is an existing property of
  every source in this codebase that uses `.timeout()` this way
  (`webdock_source.dart`, `uptime_kuma_metrics_source.dart` included), not
  something new here. It matters more for Docker specifically because a
  fleet of many containers polled at `concurrency: 4` against a genuinely
  hung daemon could accumulate open sockets faster than those sources
  ever would; `StatsMode.none` is the documented way out for a large
  fleet, not a code fix.

**CPU%/mem, and what the live capture actually revealed** (`docker_dto.dart`):
`(cpu.total - precpu.total) / (system - presystem) * online_cpus * 100`,
null (not a divide-by-zero, not a NaN, and — fixed after `refuter` review
caught the first version missing this — not a negative percent either)
when `precpu.total == 0` (the documented Podman quirk), `system -
presystem <= 0`, `cpu.total - precpu.total < 0` (a cgroup counter that
went backwards between the two snapshots, e.g. the container restarted
mid-window), or any of the four inputs is missing. mem = `usage -
(inactive_file ?? cache ?? 0)`, floored at null rather than a negative
number when the offset exceeds `usage` (seen in practice right after a
container starts, before its cgroup memory stats stabilize) — also a
`refuter`-caught fix, not part of the original formula. Three things only
the live capture surfaced, none of which the plan's own text called out:
- A **stopped container's** `/stats` response is `200 OK`, not an error —
  but `memory_stats` is `{}` and `cpu_stats` has no `system_cpu_usage` key
  at all. Both DTOs treat every field as optional for exactly this reason.
- A **never-started container** (`docker create`, not yet `start`ed)
  reports `StartedAt` as the Go zero-time sentinel
  (`"0001-01-01T00:00:00Z"`), not an absent field or `null`. Parsing it
  literally would produce a container that's apparently been running
  since the year 1; `DockerContainerInspectDTO` checks for this sentinel
  explicitly and maps it to a null `startedAt`.
- This machine's Docker Engine (29.4.0, API 1.54) still populates
  `precpu_stats` meaningfully under `stream=false` (not the
  `one-shot=true` zeroing the plan warns about), confirming the plan's
  own guidance was right to call out `one-shot=true` specifically, not
  `stream=false` generally.

**`StatsMode`** (`full` default, `none`): not in the plan's own
`DockerSource` snippet by name, but the plan's own prose says stats
default to `full` via a `StatsMode` parameter, implying at least one
other mode exists. `none` skips every per-container request, returning
only what `/containers/json` itself carries (id, name, image, state) —
the fast path for a very large fleet, at the cost of health/restarts/
CPU/mem all reading as unavailable.

**Panel** (`lib/features/containers/presentation/`): `containers_panel.dart`
(loading/error/success states, mirroring `MonitorPanel`'s structure more
than `VitalsPanel`'s, since both are "a list of typed items with state"),
`container_row.dart` (glyph from state+health, uptime formatted D/H/M/S,
restart count amber when nonzero, CPU%/MEM with `—` for null),
`containers_skeleton.dart` (no dedicated test, matching every other
loading skeleton in this codebase — none have one). Column set matches
the plan exactly: glyph · name · image (dim) · uptime · restarts (amber
when > 0) · CPU% · MEM, footer `N RUNNING · M EXITED`.

**Demo mode**: `DemoContainerSource` + `demoContainerSpec` weren't in the
plan's own Phase 2.2 text, but every other domain (host, uptime) already
has a demo counterpart specifically so demo mode and the golden harness
can showcase a feature without needing real infrastructure; leaving
containers out would make the "headline panel" invisible in exactly the
context (`--dart-define=KUROKAN_DEMO=true`, screenshots) where it matters
most. Four fixed containers (running+healthy, running+no-healthcheck,
running+starting-health, exited), `incident` scenario pins one unhealthy
with restarts, `calm` never does — same pattern as the existing demo
sources.

Known, accepted, not fixed here: the per-instance `http.Client` a Docker
`ProviderSpec.create()` builds (unlike every other provider, which reuses
the one shared `httpClientProvider` instance) is never explicitly closed
when `containersSourceProvider` is invalidated. `ContainerSource`'s
interface (per the plan's own snippet) has no `close()`/dispose hook to
call even if `containers_provider.dart` wanted to; adding one would mean
deviating from the plan's stated interface for a leak that only matters
across a config-settings change (rare) and costs one small idle
`HttpClient`, not a growing leak. `stat_tile.dart`'s pre-existing `warn`-
level gap and `dashboard_screen.dart`'s pre-existing `_openSettings` gap
(both Phase 1.4/1.5/2.0) remain untouched by this diff.

Codecov's PR comment flagged `docker_source.dart`'s `HttpException`/
`TlsException` catch branches, the one thing this entry originally
called "accepted, matching an existing gap in `webdock_source.dart`."
Haziq pushed back on treating that as good enough: unlike a genuinely
hard-to-trigger condition (a real TLS handshake failure over a real
socket), a `MockClient` callback can throw either exception type directly
with no special setup, so there was no real reason to leave them
uncovered. Fixed with two more tests; `docker_source.dart` is now 100%
covered. `webdock_source.dart`'s identical gap is untouched (out of scope
for this diff) but is the same easy fix if it comes up again.

`config.example.json` gained a `docker` entry under `containers` (with
`endpoint: "auto"`), and `config_example_test.dart` gained an assertion
that it actually parses; `docs/config.schema.json` needed no change,
since `containers` and its generic `sourceEntry` shape already covered
provider-specific settings fields like `endpoint` before this phase.

Not done here, deliberately: `docs/PROVIDERS.md` (the plan's own
"documentation deliverables" list marks it "Phase 2", not specifically
2.2). A walkthrough is more useful once there's more than one real
example to generalize from; deferred to later in Phase 2.

## 2026-09-25 — Post-2.2 bugfix pass: Vitals grid sizing, Containers header, demo mode

After #12 merged, running the real app against a real Docker daemon
surfaced three bugs no golden or widget test had caught, since all three
only show up with real window resizing or real demo-mode wiring rather
than the fixed-size harness widths existing tests use.

**demoConfig() never included a containers source.** `DemoContainerSource`
and `demoContainerSpec` were built in Phase 2.2 specifically so demo mode
could show the headline panel without real infrastructure, but the entry
was never actually added to `demoConfig()`, so "Try with demo data" never
rendered a Containers panel. Fixed by adding the entry; `dashboard_golden_test.dart`'s
overrides and both golden PNGs (regenerated on Linux CI, see below) updated
to match the panel now appearing in the harness's own render.

**Containers panel's NAME header wrapped to two lines** instead of
ellipsizing, because `ContainersColumnHeader`'s header `Text` widgets
had no `maxLines`/`overflow`/`softWrap` set at all — only the row data
cells did. Fixed by adding the same single-line/ellipsis protection to
every header cell, plus narrowing the fixed IMAGE/UP/RST/CPU/MEM column
widths slightly to leave NAME more room in practice.

**Vitals grid tiles (Disk/Network) went invisible at narrower window
widths — the more involved fix, and one that took three iterations to
get right:**

The grid picked its column count from width alone,
`(constraints.maxWidth / 151).floor()`. That formula decreases columns
as the window narrows, but fewer columns for the same 4 tiles means more
*rows*, and more rows shrinks the per-row height budget even when the
panel's actual available height hasn't changed at all — a purely
width-driven resize was silently starving vertical space. The original
Phase-1.5-era code used a fixed 112px tile height regardless of row
count, which just clipped the trailing row outright; a first fix made
tile height responsive to the real per-row budget but floored it at
90px, which fixed that case but reintroduced the same clipping bug
whenever the real budget dropped below 90 (forcing the grid taller than
the space it was actually given, since the floor was enforced by
clamping *up*, not down). A second attempt removed the floor entirely
and leaned on `StatTile`'s own `FittedBox(fit: BoxFit.scaleDown)` as the
only size-adaptation mechanism — this avoided clipping, but a
moderately (not extremely) narrow window would shrink tiles enough that
FittedBox scaled the whole tile, including the large percentage number,
down to illegible text.

The actual fix addresses the root cause instead of retuning the same
threshold a third time: maximize columns (i.e. minimize rows) down to a
much narrower per-tile minimum (70px, versus the original 151px), trying
4 → 3 → 2 → 1 in that order and taking the first that fits. This keeps
all 4 tiles in a single row for most realistic window widths, so row
height stays governed by the panel's actual available height rather than
by how many columns an arbitrary per-tile "comfortable width" allowed.
Tile height is then capped at the real per-row budget with no floor
(`rowBudget.clamp(1.0, 112.0)`) — it can never be forced above what the
grid was actually given, which is the invariant that actually prevents
clipping; `FittedBox` remains as the safety net for genuinely short
panels (two Vitals panels stacked in a narrow column, the existing
`dashboard_screen_test.dart` regression case), which is now a rarer case
than before since maximizing columns avoids most of what used to trigger
it.

Separately, the halftone accent dot was a `Positioned` child in a
`Stack` wrapping the whole panel body, anchored to the body's own
bottom-right corner. Since the grid's `Expanded` filled that same body,
the dot painted *on top of* whatever tile content reached that corner —
visible as an odd dot pattern in the middle of the panel instead of a
corner accent, reported directly from a running build. Fixed by giving
the grid a content-sized `SizedBox` (exactly `rows * tileHeight +
spacing`, not stretched to fill the remaining `Expanded`) followed by a
sibling `Expanded(Align(bottomRight: ...))` for the dot — a structural
fix, not a positioning tweak, so the dot can only ever land in space the
grid didn't use.

Golden PNGs regenerated via a throwaway `tmp/golden-regen` branch and
workflow (push-triggered on ubuntu, `flutter test --update-goldens -t
golden`, artifact uploaded, downloaded locally, branch deleted after) —
goldens only compare reliably on Linux (see `flutter_test_config.dart`),
so this stays the standing technique for any diff that changes rendered
demo-mode output.

## 2026-09-25 — Prometheus + node_exporter (Phase 2.3)

`lib/features/vps/data/prometheus_dto.dart` + `prometheus_node_source.dart`:
`PrometheusNodeSource` is the first `HostsSource` that can return more than
one `HostVitals` from a single config entry — one Prometheus server scraping
N node_exporter targets becomes N hosts, rendered by the `HostTablePanel`
Phase 2.0 already built for exactly this case. One `GET /api/v1/query` per
metric via `Future.wait` (14 in total: `node_uname_info` for the host list
and names, `up` for status, cpu/mem/disk/net, `node_load1|5|15`, uptime,
`node_procs_running`), joined across queries by the `instance` label. An
empty result vector for one metric degrades just that gauge to null for the
affected host(s) (`ParseError` only for a genuinely malformed response, e.g.
a non-vector `resultType`), matching the plan's explicit requirement and
tested directly (`test/features/vps/data/prometheus_node_source_test.dart`).

Live-verified against Haziq's own Prometheus (an EMAS-box instance scraping
4 real VPS node_exporters) before writing any fixture, which surfaced two
things the plan's own query list didn't anticipate:

- Real-world Prometheus setups commonly scrape different node_exporter
  targets under *different* `job` labels (one job per host, in this case),
  not one shared job. That ruled out using `job` as the mechanism for
  discovering which targets are node_exporter hosts — a plain `up` query
  also matched an unrelated application-metrics job on the same instance
  that happens to share the box. Host discovery instead comes from
  `node_uname_info`, which only node_exporter targets ever export, so a
  non-node_exporter `up` target simply never becomes a Kurokan host
  regardless of its job label. `job`/`instanceRegex` remain optional
  settings for the (less common) case of a single Prometheus scraping
  multiple *node_exporter* fleets that need to stay in separate config
  entries.
- Auth: Prometheus itself has no built-in auth; confirmed directly by
  querying Haziq's real endpoint with no credentials at all. `PromAuth` is
  therefore optional (`null` sends no Authorization header at all) with a
  single bearer-token field as the only auth mode shipped — the escape
  hatch for a self-hoster running Prometheus behind an authenticating
  reverse proxy. HTTP Basic auth was deliberately left out: no evidence any
  target setup needs it, and it's trivial to add later behind the same
  `PromAuth` type without a breaking change.

Test fixtures (`test/fixtures/prometheus/*.json`) are synthetic, not the
real captured responses: the repo is public, and Haziq's real fixture data
would have leaked his actual server IPs, hostnames, and job names. Every
fixture's *shape* (label sets, `resultType: "vector"`, the
`[epoch_seconds, "value_string"]` sample tuple, which labels survive a
`by(instance)` aggregation vs. a plain selector) was validated against the
real endpoint first; only the identifying values were swapped for
TEST-NET-3 addresses (`203.0.113.0/24`, already used in `webdock` fixtures)
and generic host/job names.

Model mapping: memory/disk gauges convert bytes to MiB (matching the
`Gauge`/`vitals_panel.dart` convention `webdock_source.dart` already
established — the UI's sub-text formatting for those two hardcodes a
divide-by-1024 to reach GB, so any provider's raw units must agree on MiB
in, not just "some byte-derived number"). Network sums 24h receive +
transmit into GiB; `allowed` is the optional `networkQuotaGiB` setting or
null (renders as an unbounded/"—" tile via the same `Gauge` convention
webdock already relies on when a resource has no natural cap). CPU reuses
`Gauge.fromUsedAllowed(percent, 100, unit: '%')` rather than a new gauge
constructor, since PromQL already yields a 0-100 percent directly; this
does mean the tile's generic `sub` text (`used / allowed unit`, shared
across every `HostsSource`) renders as e.g. "82.0 / 100.0 %" for
Prometheus, mildly redundant against the tile's own big percent number —
a pre-existing quirk of that shared, provider-agnostic sub-text format
(webdock's own CPU tile has the same "raw used/allowed, unit" shape), not
a new problem worth a UI change for one provider.

`HostVitals.cpu` is non-nullable by existing model contract (every current
provider always has one); a missing `node_cpu_seconds_total` sample for a
live node_exporter target isn't expected in practice, so that case
degrades to an explicit "unavailable" gauge rather than changing the
shared model's nullability for an unreached edge.

Not done here: no settings-form field for any of this yet (Phase 3's
job); `docs/config.schema.json` needed no change (same reasoning as
Phase 2.2's Docker entry — `sourceEntry`'s generic settings shape already
covers provider-specific fields). `config.example.json` gained a second
`hosts` entry demonstrating `prometheus` alongside the existing `webdock`
one.

`refuter`'s first pass on this phase's PR (#14) caught real bugs, not
nitpicks, in the original design:

- **A host that goes down would silently vanish instead of showing
  down.** The original host-discovery query was a plain instant
  `node_uname_info`. Prometheus writes a stale marker for every series a
  target previously exposed the moment a scrape fails — except `up`
  itself, which Prometheus always records (as 0) on every scrape attempt
  regardless of success. A plain `node_uname_info` query therefore stops
  returning a downed host almost immediately, which is the opposite of
  what a monitoring dashboard should do with its main failure case. Fixed
  by wrapping the name query in `last_over_time(node_uname_info{...}[1h])`,
  which keeps a host's last-known name queryable for up to an hour after
  it stops being scraped — long enough for `up=0` to still join against it
  and render `status: 'error'` instead of the host disappearing.
- **Joining every query on `instance` alone risked mixing up two
  different jobs that share an instance label.** This phase's own
  live-verification against a real deployment had already found that a
  plain `up` query matches non-node_exporter targets sharing a box with a
  node_exporter target; the fix at the time (deriving the host list from
  `node_uname_info` instead of `up`) didn't fully close the gap, since
  `up`, `node_load1`, disk, and every other per-host map were still keyed
  by `instance` only. Fixed by joining every one of the 14 queries on
  `(job, instance)` instead — including adding `job` to the two
  `by(instance)` aggregations (cpu, network), which previously dropped the
  label entirely.
- **`_sel()` interpolated `job`/`instanceRegex` into a PromQL string
  literal unescaped.** A regex containing an ordinary backslash escape
  (this phase's own test used `10\..*`, a private-IP-prefix filter) broke
  every one of the 14 queries against a real Prometheus with a
  "bad_data: unknown escape sequence" lexer error — exactly the kind of
  value these two optional settings exist to accept. Fixed with a small
  escape helper (`\` → `\\`, `"` → `\"`) applied to both settings before
  interpolation.
- Two smaller robustness gaps: `PromSampleDTO.fromJson` used `double.parse`
  directly, which throws a raw `FormatException` (escaping the
  `FetchError` hierarchy every other failure in this source goes through)
  on Prometheus's abbreviated `+Inf`/`-Inf` sample values (Dart's
  `double.parse` only understands the unabbreviated `Infinity`); and
  `.round()` was called on `NaN`/`Infinity` sample values without a guard,
  throwing `UnsupportedError`. Both are valid PromQL sample values (a
  `rate()` across a counter reset, a `0/0` in some derived expression),
  rare but real. Fixed: `+Inf`/`-Inf` are normalized before parsing, any
  other unparseable value throws `ParseError` explicitly, and a `_finite()`
  guard treats `NaN`/`Infinity` the same as a missing sample (degrades the
  gauge to null) rather than crashing.
- One relabeling, not a logic fix: the `networkQuotaGiB` field was labeled
  "GiB/mo" but compared against a 24h rolling window (the plan's own
  explicit spec — kept as-is, since a 24h figure is more responsive for a
  live dashboard than a static monthly one that barely moves), making the
  displayed percentage read as roughly 1/30th of what a literal "per
  month" quota would suggest. Relabeled to "GiB per 24h" with a hint
  spelling out the comparison window, rather than changing the query to
  match the old label.

All fixes covered by new tests in
`test/features/vps/data/prometheus_node_source_test.dart` (a host missing
from `up` entirely but still present via `last_over_time`; escaped
job/instanceRegex values with both a backslash and a quote; a NaN sample
degrading a gauge instead of crashing on `.round()`; Prometheus's
`+Inf`/`-Inf` parsing without throwing; a genuinely unparseable sample
value still throwing `ParseError`), fixture files updated to include the
`job` label the new `(job, instance)` keying requires. Second `refuter`
pass confirmed clean before merge.
