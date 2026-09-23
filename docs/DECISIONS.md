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
