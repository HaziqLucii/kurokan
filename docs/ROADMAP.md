# Roadmap

Public checklist version of the v2 expansion plan. Internal detail (verified
facts, file lists, code shapes) lives in the private planning doc; this page
tracks status only.

- [ ] **Phase 0**: Public-repo baseline: LICENSE, CI, issue/PR templates,
      dependabot, `config.example.json` + schema (files landed; CI has not
      run on GitHub yet and the `v1.0.0` tag is not pushed).
- [ ] **Phase 1**: Core generalisation: `dart:io` seam, config schema v2,
      provider registry, demo mode, N-source polling, responsive layout.
- [ ] **Phase 2**: Providers wave 1: Uptime Kuma 2.x parsing, Docker/Podman
      containers, Prometheus/node_exporter, built-in probes, Gatus.
- [ ] **Phase 3**: Memory: settings form for N entries, history +
      sparklines, incidents timeline, desktop notifications.
- [ ] **Phase 4**: Live web demo on GitHub Pages, golden test suite, README
      hero GIF.
- [ ] **Phase 5**: Release engineering: Linux release workflow, artifact
      attestations, changelog, AUR package, local macOS dmg script, `v2.0.0`
      tag.
- [ ] **Phase 6**: Operator polish: command palette + keyboard navigation,
      local read-only MCP server, diagnostics export.

Explicitly out of scope for v2: Kubernetes, Hetzner, Healthchecks.io
providers, Homebrew cask, tray/menu-bar mode, Flatpak, SSH transport for
Docker, custom PromQL tiles, i18n, telemetry.
