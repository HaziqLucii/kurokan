# Kurokan (黒監)

[![CI](https://github.com/HaziqLucii/kurokan/actions/workflows/ci.yml/badge.svg)](https://github.com/HaziqLucii/kurokan/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/HaziqLucii/kurokan/branch/main/graph/badge.svg)](https://codecov.io/gh/HaziqLucii/kurokan)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

A native desktop pane of glass for infra you already run: read-only, no
agent, no server, no telemetry. Kurokan is a single-window Flutter dashboard
that polls Uptime Kuma and Webdock.io on an interval, replacing two daily
browser tabs. Swiss-Japanese monochrome design, with color reserved for
status: green/red monitor dots, amber/red vitals tiles. macOS first, Linux
(CachyOS, GTK) second.

![Kurokan dashboard](docs/screenshots/dashboard.png)

## Features

- Live Uptime Kuma monitor list (status, response time, 24h uptime, cert
  expiry) via the Prometheus `/metrics` endpoint
- Live Webdock VPS vitals (CPU, memory, disk, network) with threshold-based
  color accents
- Six-state per-panel model (loading/refreshing/stale/error/fresh) so a
  down source dims and shows its last-known-good data instead of going blank
- Config file watcher: edit `config.json`, the dashboard reloads live, no
  relaunch
- No plugins, no tray, no telemetry — reads two read-only APIs on an
  interval and nothing else

See `docs/PLAN.md` for the full implementation plan and `docs/DECISIONS.md`
for the decisions log.

## Getting started

```
cp config.example.json ~/.config/kurokan/config.json   # fill in your webdock/kuma values
make run              # macOS
make run-linux        # Linux
make check            # format + analyze + test, same as CI
make install-macos    # release build, copies Kurokan.app to /Applications
```

See `CONTRIBUTING.md` before opening a PR.
