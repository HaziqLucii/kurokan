# infra-monitor-dashboard: v1 implementation plan

Date: 2026-09-23. Planning pass only; no implementation code in this pass.
API and SDK facts verified today against Uptime Kuma 2.5.5 source, the
Webdock OpenAPI spec (`https://api.webdock.io/api-docs/v1/webdock-api-v1.yaml`),
the locally installed Flutter 3.44.7 SDK, and the Claude Design export in
the project root.

## Context

Haziq checks two browser tabs every day: a self-hosted Uptime Kuma instance
(service up/down) and the Webdock.io control panel (VPS vitals). This project
replaces that habit with a single-window Flutter desktop app that polls both
read-only on an interval and renders them in the Swiss-Japanese monochrome
design he generated in Claude Design. macOS first (daily work laptop), Linux
(CachyOS, GTK) second. No Windows, no mobile, no tray, no alerting, no
history in v1.

Environment as verified 2026-09-23 on the Mac:

| Item | State |
|---|---|
| Flutter | 3.44.7 stable, Dart 3.12.2, SDK at `/opt/homebrew/share/flutter` |
| Active developer dir | `/Library/Developer/CommandLineTools` (CLT only) |
| Xcode.app | not installed |
| CocoaPods | not installed |
| Swift Package Manager | on by default on stable (`flutter_tools/lib/src/features.dart:215-222`) |
| Project dir | `~/Projects/infra-monitor-dashboard`: `plans/`, the design export, nothing else |

Correction to the brief: **Xcode.app is required, CocoaPods is not.** With
SPM on and a project with zero native plugins, `flutter build macos` skips
the pod step without error (`flutter_tools/lib/src/macos/cocoapods.dart:169-173`).
The plan keeps v1 plugin-free, so CocoaPods stays uninstalled unless a
later dependency forces it.

## Design reference: the Claude Design export is the UI source of truth

`Infra-monitor dashboard design/` in the project root. Section 6 is a
transcription of it; where this plan previously guessed from the Kuro
Obsidian theme, the export wins.

| File | What it is |
|---|---|
| `infra-monitor.dc.html` | canvas of 12 frames at 1100×720: dark 1a–1f, light 1g–1l, one per state (fresh, refreshing, stale, loading, error, config). Open in a browser to view. |
| `Window.dc.html` | the component: inline-styled markup for every state. Tokens at lines 245–246, sample data 249–258, state → footer copy 272–279, refresh button behaviour 291–297. |
| `support.js` | Claude Design runtime, ignore. |

M0 moves the folder to `design/` (no spaces in the path) and commits it. The
build pass ports each widget with `Window.dc.html` open beside it.

Three places in the design show data the APIs do not expose. The plan keeps
the visual and swaps the content; each is listed under "Deviations" in
section 6 so none of them reads as a build mistake later.

## 1. Project structure

Feature-first with a thin `core/`. Two data features, a setup feature for the
config-missing state, and the dashboard shell. Small enough to hold in one
head, structured enough that a third data source is a new folder.

```
infra_monitor/
  pubspec.yaml                     # deps: flutter_riverpod, http, clock. dev: fake_async. No plugins.
  lib/
    main.dart                      # runApp(AppRoot(ConfigLoader(...)))
    app_root.dart                  # StatefulWidget: loads config, watches the dir, swaps SetupScreen <-> ProviderScope
    app.dart                       # MaterialApp, ThemeMode from config, DashboardScreen
    version.dart                   # String.fromEnvironment('APP_VERSION', defaultValue: 'dev')
    core/
      config/
        app_config.dart            # immutable model + JSON (de)serialisation
        config_loader.dart         # ConfigLoader(env, home).load() -> AppConfig | throws ConfigError(path, reason)
        config_watcher.dart        # Directory.watch on the config dir, 300ms debounce
        config_provider.dart       # Provider<AppConfig> placeholder, always overridden
      net/
        http_client.dart           # IOClient(HttpClient()..connectionTimeout = 10s), User-Agent
        fetch_error.dart           # sealed FetchError: Network / Auth / Http(status) / Parse / Timeout
      polling/
        sample.dart                # Sample<T>(value, fetchedAt)
        polled.dart                # polled<T>(): FutureProvider<Sample<T>> + Timer + retry off
      theme/
        tokens.dart                # paper/edge/raised, ink RGB, opacity steps, per theme (design lines 245–246)
        typography.dart            # every TextStyle in section 6 by name
        theme.dart                 # ThemeData light + dark from tokens
    features/
      uptime/
        domain/  monitor_status.dart, monitor_source.dart
        data/    uptime_kuma_metrics_source.dart, prometheus_text_parser.dart
        presentation/  monitors_provider.dart, monitor_panel.dart, monitor_row.dart, monitor_skeleton.dart
      vps/
        domain/  host_vitals.dart, vitals_source.dart
        data/    webdock_source.dart, webdock_dto.dart
        presentation/  vitals_provider.dart, vitals_panel.dart, vitals_skeleton.dart
      setup/
        setup_screen.dart          # design frames 1f/1l: Config panel + Setup panel, runs outside ProviderScope
        open_folder.dart           # Process.run('open' | 'xdg-open', [dir])
      dashboard/
        dashboard_screen.dart      # chrome strip (macOS only), body padding, header, 62/38 grid, watermark, margin meta, grain
        dashboard_header.dart      # wordmark, LAST hh:mm:ss, refresh button
        panel_frame.dart           # title row + body + footer row, state-driven footer copy
    shared/widgets/
        panel_title.dart           # Space Grotesk title + faint tag + trailing hairline
        kv_row.dart                # 28px label/value hairline row
        stat_tile.dart             # number + unit, label, sub; ok / warn / crit variants
        skeleton_block.dart        # tint / tint-2 bars
        err_block.dart             # inverted ERR chip + message + hint line
        dossier_button.dart        # bordered mono-uppercase button; idle / active / disabled
        status_glyph.dart          # ● ■ ◐ ○
        halftone_dot.dart          # 84×84 dot grid with radial falloff (CustomPainter)
        grain_overlay.dart         # tiled noise, overlay (dark) / multiply (light)
        hairline.dart
  assets/
    fonts/                         # OFL, bundled: Fraunces variable, Space Grotesk 400/500, Space Mono 400/700, NotoSerifJP-Light subset (監)
    images/grain-180.png           # pre-rendered feTurbulence tile from the design's NOISE svg
  test/
    core/polling/polled_test.dart
    core/config/app_config_test.dart
    core/config/config_loader_test.dart
    features/uptime/data/prometheus_text_parser_test.dart
    features/uptime/data/uptime_kuma_metrics_source_test.dart
    features/vps/data/webdock_source_test.dart
    features/dashboard/dashboard_screen_test.dart
    fixtures/  uptime_kuma_metrics.txt, webdock_server.json, webdock_metrics_now.json
  design/                          # the Claude Design export, moved here in M0
  docs/PLAN.md                     # this plan, copied in at build start
  macos/  linux/                   # generated; edits listed in M0 / M5
  Makefile                         # run, test, install-macos, install-linux, passes APP_VERSION
```

Why this shape:

- `domain/` holds the interface and the model the UI reads. `data/` talks HTTP
  and maps wire shapes into the model. `presentation/` never imports `data/`.
  That is the whole abstraction story (section 3).
- `core/polling` is the one generic piece; both features need "fetch on
  interval, keep the last good value, mark stale on failure".
- No plugins. Window chrome is set natively in `MainFlutterWindow.swift` and
  `my_application.cc`, config path comes from `HOME`, fonts are bundled,
  "open folder" is `Process.run`, version comes from `--dart-define`. That is
  what keeps CocoaPods and libsecret out.
- `shared/widgets` maps one-to-one onto the repeated visual primitives in
  `Window.dc.html`, so the port is mechanical.

## 2. State management: Riverpod 3, no code generation

`flutter_riverpod ^3.4.3` (needs Dart `^3.12`, satisfied). Hand-written
providers, no `riverpod_generator` / `build_runner`.

Why Riverpod: the app is "derived async data on a timer". `FutureProvider` +
`AsyncValue` model loading, data, error and refresh-with-previous-value as
first-class states, so the six design states in section 6 are a direct read
of `AsyncValue` flags. Fake sources drop in via `ProviderScope(overrides:)`
for widget tests and for building the UI against fixtures before the
endpoints are wired. Providers are plain Dart, no `BuildContext`, so the
polling layer is unit-testable.

Why not codegen: `build_runner`, generated files, a second thing to learn,
for seven providers.

Why not Bloc or `ChangeNotifier`: Bloc's event/state ceremony buys nothing
when the only event is "tick"; `ChangeNotifier` means hand-rolling the
loading/error/previous-value states `AsyncValue` already has.

Riverpod 3 specifics that matter here:

- **Automatic retry is on by default.** The Timer owns cadence, so polled
  providers pass `retry: (_, __) => null`. Otherwise a dead endpoint is hit by
  two mechanisms and the STALE footer under-reports.
- **A refresh after an error is `AsyncError(isLoading: true)`**, not
  `AsyncLoading`. `isLoading`, `hasError`, `hasValue` can all be true. The
  panel frame tests `isLoading` first, then `hasError`, then fresh (section 4).
- **Never throw from a synchronous provider.** It rethrows `ProviderException`
  into every `ref.watch` in `build` (red error widget) and default retry
  re-runs the body with backoff. Config is loaded outside providers
  (section 5) and `appConfigProvider` is only ever overridden with a value.
- Manual `FutureProvider` is keep-alive (only codegen defaults to
  autoDispose). Out-of-view providers pause; inert for a single always-visible
  window.
- `AsyncValue.value` no longer throws on error; `requireValue` does.

Provider inventory:

| Provider | Type | Notes |
|---|---|---|
| `appConfigProvider` | `Provider<AppConfig>` | placeholder body throws `UnimplementedError`; overridden in `AppRoot` and in tests |
| `httpClientProvider` | `Provider<http.Client>` | one `IOClient`, closed on dispose |
| `monitorSourceProvider` | `Provider<MonitorSource>` | `UptimeKumaMetricsSource(config, client)` |
| `vitalsSourceProvider` | `Provider<VitalsSource>` | `WebdockSource(config, client)` |
| `monitorsProvider` | `FutureProvider<Sample<List<MonitorStatus>>>` | via `polled()` |
| `vitalsProvider` | `FutureProvider<Sample<HostVitals>>` | via `polled()` |
| `lastRefreshProvider` | `Provider<DateTime?>` | max `fetchedAt` of the two, header `LAST` |

Polling helper, shape only:

```dart
// core/polling/sample.dart
class Sample<T> { final T value; final DateTime fetchedAt; }

// core/polling/polled.dart
FutureProvider<Sample<T>> polled<T>(
  Duration Function(Ref) interval,
  Future<T> Function(Ref) fetch,
) => FutureProvider<Sample<T>>(
  (ref) async {
    final t = Timer(interval(ref), ref.invalidateSelf);
    ref.onDispose(t.cancel);
    return Sample(await fetch(ref), clock.now());
  },
  retry: (_, __) => null,
);
```

`Sample.fetchedAt` feeds `FETCHED` / `LAST OK` in the footers and `LAST` in
the header without polluting the domain models. `clock.now()` so `fake_async`
can drive it. `onDispose` runs on both rebuild and dispose and is registered
before the first `await`, so the timer never fires on an unmounted `Ref`. The
Timer is armed before the fetch, so a failed fetch still reschedules. Manual
refresh is `ref.invalidate()` on both, debounced 5s.

## 3. Data source abstraction

Two interfaces, one per panel, returning domain models. The UI knows the
model; only `data/` knows Uptime Kuma or Webdock exist.

```dart
abstract interface class MonitorSource { Future<List<MonitorStatus>> fetch(); }

enum MonitorState { up, down, pending, maintenance }

class MonitorStatus {
  final String id;               // monitor_id label, stable list key
  final String name;
  final String type;             // monitor_type, rendered uppercase
  final MonitorState state;
  final Duration? responseTime;  // null when Kuma reports -1
  final double? uptime24h;       // monitor_uptime_ratio{window="1d"}, 0..1
  final int? certDaysRemaining;  // null when not a TLS monitor
  final bool? certValid;
}

abstract interface class VitalsSource { Future<HostVitals> fetch(); }

enum UsageLevel { ok, warn, crit }

class Gauge {
  final double used, allowed, percentUsed;
  final UsageLevel level;
  final String unit;             // "MiB", "GiB", or Webdock's CPU unit (settled in M3)
}

class HostVitals {
  final String slug, name, status, ipv4;   // status: running, stopped, rebooting, ...
  final Gauge cpu, memory, disk, network;
  final int processCount;
  final DateTime sampledAt;      // Webdock's own sample timestamp, not our fetch time
}
```

Rules that keep this cheap and honest:

- **Wire shapes stay in `data/`.** A second monitor source is one class and
  one line in `monitorSourceProvider`.
- **Sources are pure fetchers.** No timers, caching or retries inside a
  source; `core/polling` owns cadence. That is what makes them testable with
  `http.MockClient` and a fixture file.
- **Errors are typed.** `NetworkError(detail)`, `AuthError(status, service)`,
  `HttpError(status, service)`, `ParseError(detail)`, `TimeoutError`. The
  error block renders them in the design's copy format (section 6).
- **Config is injected.** Nothing under `features/` touches the filesystem.
- **One implementation per interface in v1.**

Multi-server later means `List<VitalsSource>` and a column; the interfaces
do not assume one. That is the full extent of v2 accommodation.

### 3a. Uptime Kuma source: `GET /metrics`

Verified against `server/prometheus.js`, `server/auth.js`,
`server/routers/*` at tag 2.5.5.

- **Auth:** HTTP Basic, username empty, password = API key (`uk<id>_<secret>`).
  `Authorization: Basic base64(":" + apiKey)`. Once any API key exists,
  username/password Basic stops working for `/metrics`. 401 on failure.
- **Rate limit:** 60/min on API-key auth, one token per check. A 30s poll
  uses 2/60; the 5s refresh debounce keeps `⌘R` mashing under it.
- **Families** (all gauges; parse only names starting `monitor_`, ignore
  prom-client's `process_*` / `nodejs_*`):
  - `monitor_status` 1 UP, 0 DOWN, 2 PENDING, 3 MAINTENANCE
  - `monitor_response_time` ms, `-1` → null
  - `monitor_uptime_ratio{window="1d"|"30d"|"365d"}` 0.0–1.0; take `1d`
  - `monitor_cert_days_remaining`, `monitor_cert_is_valid`
- **Labels:** `monitor_id, monitor_name, monitor_type, monitor_url,
  monitor_hostname, monitor_port` + one label per Kuma tag. Parse by name,
  never position.
- **Parser rules:** unescape `\\`, `\"`, `\n`; treat `""` and the literal
  `"null"` as absent; skip `#` lines; join families by `monitor_id`.
- **Paused monitors vanish** from `/metrics`. Accepted; fewer rows.

Why `/metrics` over the status-page JSON: covers every monitor including
unpublished ones; no status page needed; token lives beside the Webdock
token; response time, 24h ratio and cert data come free. Cost is a ~50 line
parser, the most unit-testable code in the app.

Drop-in alternative, not built: `GET /api/status-page/{slug}` and
`GET /api/status-page/heartbeat/{slug}` (`heartbeatList[id]`,
`uptimeList["<id>_24"]`), no auth, only monitors in public groups. `/metrics`
is the only API-key read endpoint Kuma has.

### 3b. Webdock source: two GETs per poll

Verified against the OpenAPI spec (changelog 1.1.1).

- **Base:** `https://api.webdock.io/v1`, `Authorization: Bearer <token>`.
  Token from Account Area → API & Integrations → generate; permission
  `read:servers` only. Shown once.
- **Rate limit:** 5000/hr per account; `X-RateLimit-*` headers. Spec never
  names a 429; treated as `HttpError`, next tick retries.
- **`GET /servers/{slug}`** → `ServerDTO`: `slug, name, status, ipv4,
  profile, location, lastchecked, ...`. `status` enum: `provisioning,
  running, stopped, error, rebooting, starting, stopping, reinstalling,
  suspended`.
- **`GET /servers/{slug}/metrics/now`** → `InstantServerMetricsDTO`:
  - `cpu.latestUsageSampling {amount, timestamp}`: **whole CPU-seconds in
    the last 30-minute window**, not a percentage.
  - `memory.latestUsageSampling`: MiB in use now.
  - `disk.allowed` (MiB) + `disk.lastSamplings {amount, timestamp}` (MiB
    used; the key really is `lastSamplings`, singular object).
  - `network.total` / `network.allowed` (GiB, month to date).
  - `processes.latestProcessesSampling`.
  - `resourceUsageStatus`: `level (ok|warn|crit)` and one block each for
    `cpu, memory, disk, network` with `used, allowed, percentUsed,
    warnThresholdPercent, criticalThresholdPercent, thresholdHit, level`.
- **Mapping:** the four `Gauge`s come straight from `resourceUsageStatus.*`.
  `sampledAt` = memory sample timestamp. No `GET /profiles` call.
- **Settle with the first curl in M3:** the unit of
  `resourceUsageStatus.cpu.used/allowed` (spec says "the metric's base
  unit"). The CPU tile's sub line is written after seeing real numbers.
- **Not exposed anywhere:** load average, server uptime, per-process detail,
  live CPU %. This forces the deviations in section 6.

## 4. State model per panel

Each panel derives one of six states from its own `AsyncValue<Sample<T>>`.
The design's `state` prop applies to the whole window; in the app the two
panels are independent because failures are per source.

| Order | Predicate | Design state | Footer left | Footer right |
|---|---|---|---|---|
| 1 | `isLoading && !hasValue` | loading | `LOADING` | `—` |
| 2 | `isLoading && hasValue` | refreshing | `REFRESHING` | count / `POLL 30S` |
| 3 | `hasError && hasValue` | stale | `STALE · LAST OK 14:31:37 · TIMEOUT` | count / `POLL 30S` |
| 4 | `hasError` | error | `ERROR · 14:32:07` | `RETRY 30S` |
| 5 | else | fresh | `FETCHED 14:32:07` | `08 MONITORS · 01 DOWN` / `POLL 30S` |

Stale dims the panel body to `ink-dim` (design: `--ink` overridden to
`a(dim)` on the body; Flutter: `Opacity(0.86)` on the panel body). The
error kind in the stale footer is the `FetchError` name uppercased. Header
`LAST` shows `--:--:--` until the first `Sample` exists. Times are local
`HH:mm:ss`.

## 5. Configuration

Plain JSON, created by hand, mode 0600. Path `~/.config/infra-monitor/config.json`
on both platforms; `INFRA_MONITOR_CONFIG` overrides it.

```json
{
  "webdock": { "slug": "webdock-prod-01", "apiToken": "..." },
  "kuma":    { "url": "https://status.example.tld", "apiKey": "uk1_..." },
  "pollIntervalSec": 30,
  "theme": "system"
}
```

Key names follow the design's `EXPECTED SHAPE` block with two content
corrections: `server` → `webdock` (two services, "server" is ambiguous) and
`kuma.username/password` → `kuma.apiKey` (username/password Basic auth is
dead on `/metrics` once an API key exists, see 3a). `theme` is
`system | dark | light` → `ThemeMode`. Default poll 30s as designed.

Why not Keychain / `flutter_secure_storage`: macOS needs a
`keychain-access-groups` entitlement and provisioning profile; Linux needs
`libsecret` plus a running Secret Service, which a CachyOS box on a bare WM
may not have, and the failure is silent. A 0600 file next to `~/.kube/config`
is the trust level he already accepts.

Why one path on both OSes (deviation from the design's `~/Library/Application
Support/...` row for macOS): one path to remember, one `.desktop`/Makefile,
and he already lives in `~/.config`. The Setup screen shows a single row
labelled with the current OS.

### Loading, watching, and the setup screen

No settings UI. The config-missing state is the design's frames 1f/1l: a
`Config · NOT FOUND` panel (path row, `EXPECTED SHAPE` pre block) and a
`Setup · 04 STEPS` panel (numbered steps, `OPEN CONFIG FOLDER` button,
halftone accent), footers `NO CONFIG · WATCHING FOR FILE` / `RELOADS ON SAVE`
and `FIRST LAUNCH` / `V0.1.0`.

The footer copy commits the app to watching the file, so it does:

```dart
// app_root.dart, shape only
class _AppRootState extends State<AppRoot> {
  AppConfig? cfg; ConfigError? err; int gen = 0;
  void initState() {
    Directory(loader.dir).createSync(recursive: true);   // so watch + open-folder work on first launch
    _tryLoad();
    sub = ConfigWatcher(loader.dir).events.listen((_) => _tryLoad());
  }
  void _tryLoad() => setState(() { try { cfg = loader.load(); err = null; gen++; } on ConfigError catch (e) { cfg = null; err = e; } });
  Widget build(_) => cfg == null
    ? SetupScreen(error: err, onOpenFolder: () => openFolder(loader.dir))
    : ProviderScope(key: ValueKey(gen), overrides: [appConfigProvider.overrideWithValue(cfg!)], child: App(config: cfg!));
}
```

`Directory.watch()` is FSEvents on macOS and inotify on Linux, no plugin.
Any event debounced 300ms → reload attempt. `ValueKey(gen)` rebuilds the
`ProviderScope` on every successful reload, so editing the interval or a
token while running takes effect without a relaunch. `ConfigLoader` takes
`env` and `home` as constructor arguments because `Platform.environment`
cannot be set from a test. `openFolder` is `Process.run('open', [dir])` on
macOS and `xdg-open` on Linux.

### macOS App Sandbox: off

Template entitlements verified at
`/opt/homebrew/share/flutter/packages/flutter_tools/templates/app/macos.tmpl/Runner/`:
`DebugProfile` has `app-sandbox`, `cs.allow-jit`, `network.server`;
`Release` has `app-sandbox` only. Neither has `network.client`, so outbound
HTTP fails in both builds, and `~/.config` is unreadable from the container.
Personal app, never App Store: M0 sets `app-sandbox` to `false` in both.
Template signs ad hoc with no hardened runtime, so no signing change is
needed for the entitlements to apply.

## 6. UI: transcription of `Window.dc.html`

The design uses the browser default root size, so `1rem = 16px`. Every value
below is from the file; nothing is eyeballed. Fonts are bundled and set via
`FontVariation` where the design uses variable axes.

### Tokens (`tokens.dart`, from lines 245–246)

| Token | Dark | Light |
|---|---|---|
| paper | `#0b0a09` | `#ece7dd` |
| edge (chrome strip) | `#050504` | `#e6e0d5` |
| raised (pre block) | `#100e0d` | `#e3ddd1` |
| ink RGB | `205,196,186` | `38,34,29` |
| dim / muted / faint | .86 / .60 / .40 | .82 / .58 / .38 |
| line / line-soft / line-strong | .20 / .10 / .42 | .22 / .11 / .45 |
| tint / tint-2 | .05 / .10 | .045 / .09 |
| grain blend / opacity | overlay / .04 | multiply / .05 |

Every colour is a paper or `ink.withOpacity(step)`. No accent hue. No radius
anywhere in the design (sharp corners), no shadows.

### Window and chrome

- Preview 1100×720, `min-width 800 / min-height 520`.
- 28px chrome strip, `edge` background, 1px `line-soft` bottom, three 11px
  hollow circles with a `line-strong` 1px border at 12px padding, 8px gap.
  On macOS this is rendered by us under a transparent native titlebar (M0);
  the real traffic lights sit on top of it, coloured. On Linux the strip is
  not drawn; the WM header bar takes its place.
- Body: `padding 22 40 22 60`, column, gap 20, `overflow hidden`.
- Watermark `監`: Noto Serif JP 300, size `clamp(180px, 30cqw, 440px)`
  (cqw = body width), `line-height 1`, ink at .035, positioned
  `right -1.5%` `bottom -10%` of the body.
- Margin meta: `left 20 / top 22 / bottom 22`, vertical, reads bottom-to-top
  (`vertical-rl` + `rotate(180deg)`), Space Mono 10px, `0.34em`, uppercase,
  faint: `<slug> · POLL 30S · V<version>`.
- Grain: full-window overlay, 180px tile, blend/opacity per token table.

### Header

- Row, `align-items flex-end`, `space-between`, gap 24, `padding-bottom 14`,
  1px `line` bottom.
- Wordmark `infra-monitor`: Fraunces `wght 300`, `opsz 144`,
  size `clamp(48px, 9cqw, 96px)`, `line-height .82`, `letter-spacing -0.03em`.
- Right column, `align-items flex-end`, gap 10, `padding-bottom 4`:
  `LAST 14:32:07` (0.62rem, `0.22em`, uppercase, muted, tabular) above the
  refresh button.
- Refresh button (`dossier_button`): Space Mono 0.6rem, `0.2em`, uppercase,
  `padding 7 12`, transparent, 1px `line-strong` border. Idle label
  `↻ REFRESH`; refreshing: `tint` background, label `REFRESHING`, cursor
  default; loading or config: opacity .45, disabled.

### Main grid

`grid-template-columns: minmax(0,62fr) minmax(0,38fr)`, gap 40, fills the
remaining height. Flutter: `Row` with `Expanded(flex: 62)`, 40px gap,
`Expanded(flex: 38)`.

### Panel frame (both panels)

- Title row: `panel_title` Space Grotesk 500, 0.78rem, `0.16em`, uppercase,
  ink; tag 0.6rem, `0.16em`, faint (`08` monitor count, `WEBDOCK`); trailing
  1px `line` hairline; `margin-bottom 6`, gap 12.
- Body: `flex 1`, `overflow hidden`.
- Footer: `padding-top 8`, 1px `line` top, 0.6rem, `0.2em`, uppercase,
  muted, tabular; left span in ink, right span muted; copy per section 4.

### Monitors panel

Column grid `22px | 1fr | 70px | 64px | 72px | 44px`, `padding 0 8`:

- Header row: height 26, 1px `line` bottom, 0.58rem, `0.2em`, uppercase,
  faint: `_ · NAME · TYPE · RESP · 24H · CERT` (last three right-aligned).
- Row: height 32, 1px `line-soft` bottom, 0.72rem, tabular, hover `tint`.
  - glyph 0.66rem (`●` ink; `◐` `○` muted)
  - name, ellipsis
  - type 0.6rem, `0.12em`, faint, `monitor_type` uppercased
  - resp right: `142ms`; `PEND` / `MAINT` muted 0.6rem `0.12em`; `—` when null
  - 24h right: `99.98%`
  - cert right: 0.62rem muted, `61D`; `!6D` when < 14 days or invalid;
    empty when not a TLS monitor
- Down row: background `ink`, text `paper`; glyph `■` 0.62rem; name 700;
  type 0.6rem `0.12em`; resp column shows `DOWN` 700, 0.64rem, `0.16em`;
  24h; cert 0.62rem.
- Skeleton (loading): 8 rows, same grid, 7px bars: glyph 7×7 `tint-2`,
  name widths `46/32/58/40/28/52/36/44%` `tint-2`, type 34px `tint`, resp
  36px `tint-2`, 24h 48px `tint-2`, cert 22px `tint`.
- Error (no data): `padding 16 8`, gap 10. Line 1: `ERR` chip (ink
  background, paper text, `padding 3 7`, 0.58rem, `0.2em`, 700) + message
  0.68rem `0.12em`. Line 2: 0.6rem `0.2em` faint.
- Overflow: rows scroll, no visible scrollbar.

Error message format by `FetchError`:

| Error | Message | Hint |
|---|---|---|
| Network | `NETWORK · <detail> <host:port> · CHECK kuma.url` | `RETRY IN 30S · ⌘R TO RETRY NOW` |
| Auth | `AUTH · 401 FROM KUMA · CHECK kuma.apiKey` | same |
| Http | `HTTP · 502 FROM KUMA` | same |
| Parse | `PARSE · <detail>` | same |
| Timeout | `TIMEOUT · 10S` | same |

`⌘R` on macOS, `CTRL+R` on Linux. `30S` is the configured interval, static,
not a countdown.

### Vitals panel

- Halftone accent (`halftone_dot`): 84×84 at `right 0 / bottom 6` of the
  body, dot grid 4px pitch, dot radius 0.9px in ink, alpha falloff radial
  from `(34%, 34%)`: 1 → .75 at 28% → .3 at 52% → 0 at 70%; whole thing at
  .55. `CustomPainter`, 441 dots, wrapped in `RepaintBoundary`.
- KV rows (`kv_row`): height 28, 1px `line-soft` bottom, label 0.6rem
  `0.16em` muted, value 0.72rem tabular:

  | Design row | App row | Source |
  |---|---|---|
  | `SERVER webdock-prod-01` | `SERVER <slug>` | `ServerDTO.slug` |
  | `STATUS ● RUNNING` (`0.12em`) | same, glyph by status | `ServerDTO.status` |
  | `UPTIME 41D 06H 12M` | `PROCS 143` | `processes.latestProcessesSampling` |
  | `LOAD 1·5·15 0.42 0.51 0.48` | `SAMPLED 14:30:00` | `sampledAt` |

  Deviation D1: Webdock exposes neither server uptime nor load average. The
  two rows keep the design's geometry with data that exists and is useful
  (process count, and the sample time so the coarse CPU window is not
  mistaken for live load).
- Tile grid: `margin-top 16`, `repeat(auto-fit, minmax(150px, 1fr))`,
  `gap 1` on a `line` background with a 1px `line` border (hairline grid).
  Tiles `paper`, `padding 14 14 12`, height 112 (matches the skeleton).
  Flutter: `LayoutBuilder` → columns = `max(1, width ~/ 151)`.
- Tile (`stat_tile`): number Space Grotesk 2.6rem, `line-height 1`,
  `-0.02em`, tabular, with unit span 0.9rem muted (`%`, ` GB`); label
  `margin-top 10`, 0.6rem, `0.22em`; sub `margin-top 3`, 0.6rem, muted,
  tabular.
  - ok: as above.
  - warn: `inset 0 2px 0 line-strong` top rule; label prefixed `! `.
  - crit: background `ink`, text `paper`; label 700, `■ <NAME> · CRIT`;
    unit at .7, sub at .72 opacity.

  | Tile | Number | Sub | Source |
  |---|---|---|---|
  | `CPU` | `percentUsed` `%` | `used / allowed <unit>` | `resourceUsageStatus.cpu`; label may become `CPU · 30M` after M3 (D2) |
  | `MEM` | `percentUsed` `%` | `12.9 / 16 GB` | `resourceUsageStatus.memory`, MiB → GB one decimal |
  | `DISK` | `percentUsed` `%` | `75.2 / 80 GB` | `resourceUsageStatus.disk` |
  | `NETWORK` | `total` ` GB`/` TB` | `1.2 / 20 TB · MTD` | `network.total/allowed` GiB month to date (design says `· 30D`) |

  Deviation D2: the design's CPU tile implies live load (`3.0 / 8 vCPU`).
  Webdock gives CPU-seconds per 30-minute window and a `percentUsed` against
  its own allowance. The number is `percentUsed`; the sub line shows
  Webdock's `used / allowed` in Webdock's unit, decided after the M3 curl.
- Skeleton: 4 KV rows with 52px label bars (`tint`) and 110/74/92/100px value
  bars (`tint-2`); 4 tiles 112px with 64×38 `tint`, 40×7 `tint-2`, 78×7 `tint`
  bars, gap 10; grid lines `line-soft`.
- Error: `padding 16 0`; `ERR` chip + `AUTH · 401 FROM WEBDOCK · CHECK
  webdock.apiToken`; hint `RETRY IN 30S`.

### Setup screen (config state)

Same chrome, header (button disabled at .45) and 62/38 grid.

- Left, `Config` + tag `NOT FOUND`: 0.7rem body. Row grid `96px | 1fr`,
  `min-height 30`, `line-soft` bottom: label 0.6rem `0.16em` muted (`MACOS`
  or `LINUX`, current OS only, D3), value = path. Then `EXPECTED SHAPE`
  (0.58rem, `0.2em`, faint, `margin-top 18`) and a pre block (`margin-top 8`,
  `padding 14 16`, 1px `line` border, `raised` background, Space Mono
  0.68rem, `line-height 1.65`) containing the section 5 JSON with tokens
  masked as `••••`. Footer `NO CONFIG · WATCHING FOR FILE` / `RELOADS ON SAVE`.
  When the file exists but is invalid, the tag reads `INVALID` and the pre
  block is preceded by the `ConfigError.reason` in the error-message style.
- Right, `Setup` + tag `04 STEPS`: 0.68rem, `line-height 1.5`, rows
  `32px | 1fr`, `padding 8 0`, `line-soft` bottom, index faint:
  `01 Create config.json at the path above.` · `02 Add the Webdock server
  slug and apiToken.` · `03 Add the Uptime Kuma url and apiKey.` · `04 Save.
  The dashboard loads on its own.` Then `OPEN CONFIG FOLDER` button
  (`padding 8 12`), halftone accent bottom-right. Footer `FIRST LAUNCH` /
  `V<version>`.

Deviation D3: one config path on both OSes (section 5), so one path row.

### Fonts (bundled, OFL)

| Family | Files | Used for |
|---|---|---|
| Fraunces | variable `Fraunces[SOFT,WONK,opsz,wght].ttf`; `FontVariation('wght', 300)`, `('opsz', 144)` | wordmark |
| Space Grotesk | 400, 500 | panel titles, tile numbers |
| Space Mono | 400, 700 | everything else |
| Noto Serif JP | Light 300, subset to `監` via `pyftsubset --text=監` | watermark only |

Full Noto Serif JP Light is several MB; the subset is a few KB. If
`fonttools` is not to hand, `brew install fonttools` (or `pipx install
fonttools`) once.

### Grain

The design's `NOISE` is an inline SVG: `feTurbulence fractalNoise
baseFrequency .85 numOctaves 2 stitchTiles`, desaturated, 180×180. Render it
once to `assets/images/grain-180.png` (`rsvg-convert` from `librsvg`, or a
browser screenshot at 1×). In Flutter: root `CustomPaint(foregroundPainter:)`
drawing an `ImageShader` tile with `Paint.blendMode = overlay` (dark) /
`multiply` (light) at the token opacity. If the blend composites wrongly
across layers, fall back to `srcOver` at the same opacity; at 4% the
difference is not visible.

### Typography map (`typography.dart`)

| Name | Font | px | Tracking | Notes |
|---|---|---|---|---|
| `marginMeta` | Mono | 10 | 0.34em | uppercase, faint |
| `wordmark` | Fraunces 300/opsz144 | clamp(48, 9% w, 96) | -0.03em | lh .82 |
| `lastLabel` | Mono | 9.92 | 0.22em | uppercase, muted, tabular |
| `button` | Mono | 9.6 | 0.2em | uppercase |
| `panelTitle` | Grotesk 500 | 12.48 | 0.16em | uppercase |
| `panelTag` | Mono | 9.6 | 0.16em | faint |
| `colHeader` | Mono | 9.28 | 0.2em | uppercase, faint |
| `row` | Mono | 11.52 | 0 | tabular |
| `rowType` | Mono | 9.6 | 0.12em | faint |
| `rowCert` | Mono | 9.92 | 0 | muted |
| `glyph` / `glyphDown` | Mono | 10.56 / 9.92 | | |
| `downLabel` | Mono 700 | 10.24 | 0.16em | |
| `kvLabel` | Mono | 9.6 | 0.16em | muted |
| `kvValue` | Mono | 11.52 | 0 | tabular |
| `tileNum` / `tileUnit` | Grotesk | 41.6 / 14.4 | -0.02em / 0 | lh 1, tabular |
| `tileLabel` | Mono | 9.6 | 0.22em | |
| `tileSub` | Mono | 9.6 | 0 | muted, tabular |
| `footer` | Mono | 9.6 | 0.2em | uppercase, muted, tabular |
| `errChip` | Mono 700 | 9.28 | 0.2em | inverted |
| `errMsg` | Mono | 10.88 | 0.12em | |
| `errHint` | Mono | 9.6 | 0.2em | faint |
| `pre` | Mono | 10.88 | 0 | lh 1.65 |
| `setupStep` | Mono | 10.88 | 0 | lh 1.5 |

`em` tracking → `letterSpacing = em × fontSize`. Tabular → `FontFeature.tabularFigures()`.

### Deviations from the design, all content, none visual

| # | Design | App | Why |
|---|---|---|---|
| D1 | Vitals rows `UPTIME`, `LOAD 1·5·15` | `PROCS`, `SAMPLED` | Webdock exposes neither uptime nor load average |
| D2 | CPU tile `38%` / `3.0 / 8 vCPU` | `percentUsed` / Webdock's `used / allowed` | CPU is a 30-minute CPU-seconds window, not live load |
| D3 | Config panel shows MACOS and LINUX path rows | one row for the current OS, `~/.config/...` on both | one path decision (section 5) |
| D4 | Config shape `server{…}`, `kuma{username,password}` | `webdock{…}`, `kuma{apiKey}` | API-key auth is the only working `/metrics` auth once a key exists |
| D5 | Network tile `· 30D` | `· MTD` | Webdock's figure is month to date |
| D6 | Types `HTTPS`, `SMTP`, `TCP` | Kuma's `monitor_type` uppercased (`HTTP`, `PORT`, `PING`, `KEYWORD`, …) | Kuma has no `https`/`smtp` type |
| D7 | macOS traffic lights drawn as hollow monochrome circles | native coloured traffic lights over our strip | hiding them removes the close button; not worth it in v1 |

## 7. Scope call-outs

**In v1 because the design commits to it (not on the original list):**

1. **Config file watcher with live reload** (`WATCHING FOR FILE · RELOADS ON
   SAVE`). ~20 lines with `Directory.watch`, no plugin, and it removes the
   relaunch from first-run and from every token or interval edit.
2. **`OPEN CONFIG FOLDER` button.** `Process.run`, one line per OS.
3. **`theme` key** (`system | dark | light`). Two lines; the design ships a
   light mode, so it should be reachable without changing the OS setting.
4. **Transparent macOS titlebar with our chrome strip.** Four lines of Swift
   in M0. Marked optional: if it fights back, ship the native titlebar and
   move on.

**In v1 because polling honestly requires it:**

5. Per-panel stale/error states and timestamps (the design's six states).
6. Manual refresh, `⌘R` / `Ctrl+R`, 5s debounce.
7. Typed fetch errors rendered in the design's `ERR` copy format.
8. 24h uptime ratio and cert days per row; both in the `/metrics` body already.

**Stays out, agreed:**

- Multi-server / multi-instance. Interfaces do not assume one; nothing built.
- Historical charts / storage. Nothing persisted, no ring buffer. Webdock's
  non-`now` `/metrics` with 7-day samplings is the v2 source.
- Tray / menu bar. v2. `tray_manager` + `window_manager` + hide-on-close;
  both are plugins and that is when CocoaPods may become relevant.
- Notifications. Out. `resourceUsageStatus.level` and `monitor_status` are
  the signals a v2 would key off.
- Settings UI. The setup screen shows the shape; the editor is the UI.
- A live `RETRY IN` countdown. The design's text is static; keep it static.

## 8. Milestones

Each ends in something that runs. M0 is manual. M1–M4 build on Sonnet and
get refuted by the `refuter` agent before being called done. M5 needs the
Linux machine.

### M0: toolchain, empty app, design in repo (macOS, manual)

1. Install Xcode.app (App Store or `xcodes`), then:
   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   sudo xcodebuild -license accept
   flutter doctor -v
   ```
   Xcode line green. The CocoaPods warning stays and is ignored.
2. Server-side prerequisites: Uptime Kuma ≥ 1.21 with an API key (Settings →
   API Keys); Webdock API key with `read:servers`. Both must return 200
   before M2/M3:
   ```
   curl -u ":$KUMA_KEY" https://status.example.tld/metrics | head
   curl -H "Authorization: Bearer $WD_TOKEN" https://api.webdock.io/v1/servers/$SLUG/metrics/now
   ```
3. ```
   cd ~/Projects/infra-monitor-dashboard
   mv "Infra-monitor dashboard design" design
   flutter create --platforms=macos,linux --project-name infra_monitor --org dev.haziq .
   git init && git remote add origin git@github.com:HaziqLucii/infra-monitor-dashboard.git
   ```
   Remote first so the `includeIf` identity rule and `gh` autoswitch apply
   before the first commit. `--org` is any personal reverse-DNS.
4. `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:
   `app-sandbox` → `false`. Leave `cs.allow-jit`.
5. `MainFlutterWindow.swift`, after the template's `setFrame` line:
   `setContentSize(1100×720)`, `contentMinSize = 800×520`, `title`,
   `center()`. Then, optional (call-out 4): `titlebarAppearsTransparent =
   true`, `titleVisibility = .hidden`, `styleMask.insert(.fullSizeContentView)`,
   `isMovableByWindowBackground = true`. Verified against the 3.44 template:
   the size lines must come after `setFrame` or they are overwritten;
   `contentMinSize` not `minSize`; `center()` because resizing keeps the
   bottom-left origin and the xib's origin pushes the title bar off a 900pt
   display.
6. Asset prep (one-off, no code): download the four font families from
   Google Fonts' GitHub, `pyftsubset` Noto Serif JP Light to `監`, render
   the grain SVG to `grain-180.png`. Commit under `assets/`.
7. `flutter run -d macos`. **Demo:** template counter app in a native window
   at the intended size, centred, with the design committed under `design/`.

### M1: skeleton, config, setup screen, theme

- `pubspec.yaml`: `flutter_riverpod ^3.4.3`, `http ^1.6.0`, `clock`, font
  assets; `fake_async` dev.
- `core/theme` (tokens, typography map, themes), `core/config` (model,
  loader with injected `env`/`home`, watcher), `app_root.dart`,
  `features/setup`, `shared/widgets` (panel_title, kv_row, dossier_button,
  halftone_dot, grain_overlay, hairline, skeleton_block, err_block).
- `DashboardScreen` with chrome strip, header, margin meta, watermark, grain,
  and two `PanelFrame`s in the loading state (skeletons).
- Tests: `app_config_test` (round-trip, defaults, `theme` parsing),
  `config_loader_test` (env override to a temp file, missing → `ConfigError`
  with path, malformed → reason).
- **Demo:** design frames 1d/1j (loading) and 1f/1l (setup) side by side with
  the browser render. Move the config away while running: setup screen
  appears. Put it back: skeleton dashboard appears. No relaunch. `OPEN CONFIG
  FOLDER` opens Finder. Toggle `theme` in the file: light/dark swaps live.

### M2: Uptime Kuma panel

- Capture the real `/metrics` body into `test/fixtures/uptime_kuma_metrics.txt`.
- `prometheus_text_parser.dart` + tests: escaped quotes, `"null"` values, tag
  labels, `-1` response time, `process_*` ignored, join by `monitor_id`.
- `UptimeKumaMetricsSource` + `MockClient` tests: 200, 401 → `AuthError`,
  malformed → `ParseError`, `MockClient` throwing `SocketException` /
  `TimeoutException` → `NetworkError` / `TimeoutError` (no real 10s wait).
- `sample.dart`, `polled.dart` + `fakeAsync` test: container created inside
  the callback, `container.listen(...)` to keep the element active, drive
  with `async.elapse` (Riverpod's scheduler uses a zero-duration timer, so
  `flushMicrotasks` alone is not enough). Assert second fetch after one
  interval; error-after-value keeps `hasValue`; `fetchedAt` follows `clock`.
- `monitorsProvider`, `MonitorPanel`, `MonitorRow` (all four states, down
  inversion, cert `!` rule), footer copy, error block.
- **Demo:** frames 1a/1b/1c/1e for the monitors side, live. Turn Wi-Fi off:
  panel goes stale and dims, keeps the last read. Turn it on: recovers on the
  next tick.

### M3: Webdock panel

- Capture `GET /servers/{slug}` and `GET /servers/{slug}/metrics/now` into
  fixtures. Read `resourceUsageStatus.cpu.used/allowed`, decide the CPU
  sub-line unit and whether the label becomes `CPU · 30M` (D2).
- `webdock_dto.dart`, `WebdockSource` → `HostVitals`; tests incl. 401/404/429.
- `vitalsProvider`, `VitalsPanel`: four KV rows (D1), tile grid with
  ok/warn/crit variants from `level`, halftone accent, footer.
- **Demo:** both panels live. The app now replaces the two tabs.

### M4: daily-driver polish and release build

- `⌘R`/`Ctrl+R` via `Shortcuts` + `Actions`, header button states, debounce,
  `lastRefreshProvider`.
- `dashboard_screen_test`: both sources overridden with fakes; asserts a down
  row is inverted, a crit tile is inverted, a stale footer appears on
  error-after-value, and `LAST` reads `--:--:--` before first data.
- `Makefile`: `run`, `test`, `install-macos` (`flutter build macos --release
  --dart-define=APP_VERSION=$(git describe --tags --always)`, copy
  `infra_monitor.app` to `/Applications`).
- Copy this plan to `docs/PLAN.md`; `docs/DECISIONS.md` with: sandbox off,
  plaintext config, `/metrics` over status page, no plugins, D1–D7.
- **Demo:** launched from Spotlight, both themes, used daily for a week.

### M5: Linux (CachyOS)

- `sudo pacman -S --needed clang cmake ninja pkgconf gtk3` (pacman mapping of
  the documented apt list; Arch ships headers in the main packages).
- `flutter run -d linux`. Expected friction: font hinting, CJK subset
  rendering, `xdg-open` availability. Chrome strip is skipped on Linux.
- `linux/runner/my_application.cc`: default size 1100×720, title.
- `.desktop` entry + icon into `~/.local/share/applications/`;
  `make install-linux`.
- **Demo:** same dashboard on the home machine, same config file shape.

## 9. Risks and open items

- **R1** CPU tile semantics (D2). Settled by the M3 curl. If Webdock's
  `percentUsed` for CPU turns out meaningless for his profile, the honest fix
  is an exporter on the box as a second `VitalsSource`; that is a scope
  decision for Haziq, not a slip-in.
- **R2** Paused Kuma monitors vanish from `/metrics`. Accepted.
- **R3** Sandbox off means no App Store path. Recorded as a decision.
- **R4** Riverpod 3 auto-retry must be off on polled providers. In `polled()`.
- **R5** Laptop sleep: `Timer` fires late after wake; stale marker and manual
  refresh cover it. No lifecycle handling in v1.
- **R6** A later plugin without SPM support makes `brew install cocoapods` a
  one-line prerequisite. Not before.
- **R7** TLS: `dart:io` on macOS trusts the system Keychain roots, so Let's
  Encrypt works; ATS does not apply to Dart sockets, so `http://` LAN works.
- **R8** Grain blend mode across Flutter layers may not composite as CSS
  `mix-blend-mode` does. Fallback is `srcOver` at the same opacity.
- **R9** Transparent titlebar (call-out 4) may interact badly with
  `isMovableByWindowBackground` and Flutter hit-testing. If so, native
  titlebar, D7 widens, move on.
- **R10** `Directory.watch` on macOS FSEvents can coalesce or delay events by
  up to a second. Acceptable for a config file.

## 10. Verification (end to end, after M4)

1. `flutter test` green: parser, both sources, polling, config, dashboard.
2. `flutter analyze` clean.
3. `flutter run -d macos` with the real config: both panels populate within
   one interval; `LAST` advances every interval.
4. Visual diff against `design/infra-monitor.dc.html` for all six states in
   both themes at 1100×720 and at the 800×520 minimum.
5. Kill network: both panels stale, dimmed, last data kept, footer names the
   error kind. Restore: both recover on the next tick.
6. Wrong Webdock token only: vitals shows `AUTH · 401 FROM WEBDOCK · CHECK
   webdock.apiToken`; monitors unaffected.
7. Move config away while running: setup screen within ~1s. Restore: dashboard
   returns, no relaunch. Edit `pollIntervalSec`: margin meta and footer update.
8. `⌘R` refreshes both; 60 presses in a minute produce ≤ 12 requests per
   source (5s debounce).
9. `refuter` agent re-runs 1–2 and reads the full diff before M4 is called
   done; again after M5 on the Linux box.
