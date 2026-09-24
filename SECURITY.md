# Security

Kurokan is a read-only desktop client. It polls the APIs you configure on an
interval and renders the result; it sends no telemetry and has no listening
socket.

## Config file

`~/.config/kurokan/config.json` holds API tokens in plaintext and is written
with `0600` permissions on both macOS and Linux. Treat it like any other
credentials file (`~/.kube/config`, `~/.ssh/config`): back it up carefully,
never commit it, and rotate a token if the file is ever exposed.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting for this repo (Security tab ->
"Report a vulnerability") rather than a public issue. Include the version
(`git describe --tags` for a source build, or the Releases asset name) and
reproduction steps.
