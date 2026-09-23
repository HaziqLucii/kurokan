# Kurokan (黒監)

A single-window Flutter desktop dashboard that polls Uptime Kuma and
Webdock.io read-only on an interval, replacing two daily browser tabs.
Swiss-Japanese monochrome design. macOS first, Linux (CachyOS, GTK) second.

See `docs/PLAN.md` for the full implementation plan and `docs/DECISIONS.md`
for the decisions log.

## Getting started

```
cp /path/to/config.json ~/.config/kurokan/config.json   # see docs/PLAN.md section 5 for the shape
make run
make test
make install-macos   # release build, copies Kurokan.app to /Applications
```
