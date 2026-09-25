import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/providers/registry_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/err_block.dart';
import '../../../shared/widgets/halftone_dot.dart';
import '../../../shared/widgets/kv_row.dart';
import '../../../shared/widgets/source_error_text.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../dashboard/panel_frame.dart';
import '../domain/host_vitals.dart';
import 'host_status_glyph.dart';
import 'host_table_panel.dart';
import 'hosts_provider.dart';
import 'vitals_skeleton.dart';

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

({double value, String unit}) _networkScale(double allowedGiB) =>
    allowedGiB >= 1024 ? (value: 1024, unit: 'TB') : (value: 1, unit: 'GB');

class VitalsPanel extends ConsumerWidget {
  final String sourceId;
  const VitalsPanel({super.key, required this.sourceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hostsProvider(sourceId));
    final config = ref.watch(appConfigProvider);
    final pollSeconds = config.pollInterval.inSeconds;
    final entry = config.hosts.firstWhere((h) => h.id == sourceId);
    final tag =
        ref.watch(providerRegistryProvider).hostSpec(entry.provider)?.tag ??
        entry.provider.toUpperCase();

    final hasValue = async.hasValue;
    final hasError = async.hasError;
    final isLoading = async.isLoading;

    final String footerLeft;
    final String footerRight;
    final Widget body;
    var dimmed = false;

    if (isLoading && !hasValue) {
      footerLeft = 'Loading';
      footerRight = '—';
      body = const VitalsSkeleton();
    } else if (hasError && !hasValue) {
      footerLeft = 'Error · ${_time(DateTime.now())}';
      footerRight = 'Retry ${pollSeconds}s';
      body = ErrBlock(
        message: sourceErrorMessage(async.error, tag: tag),
        hint: 'Retry in ${pollSeconds}s',
        padding: const EdgeInsets.symmetric(vertical: 16),
      );
    } else {
      final sample = async.requireValue;
      final hosts = sample.value;
      footerRight = 'Poll ${pollSeconds}s';

      if (isLoading) {
        footerLeft = 'Refreshing';
      } else if (hasError) {
        dimmed = true;
        footerLeft =
            'Stale · Last ok ${_time(sample.fetchedAt)} · ${sourceErrorKind(async.error)}';
      } else {
        footerLeft = 'Fetched ${_time(sample.fetchedAt)}';
      }
      // Every current provider (webdock, demo) always yields exactly one
      // host; a source that yields several (Prometheus etc, Phase 2) gets
      // the compact HostTablePanel instead of exploding into N detail
      // tiles. An empty list isn't reachable by any current provider but
      // is handled gracefully rather than crashing on `.first`.
      body = switch (hosts.length) {
        0 => const _EmptyHostsBody(),
        1 => _VitalsBody(vitals: hosts.first),
        _ => HostTablePanel(hosts: hosts),
      };
    }

    return PanelFrame(
      title: 'Vitals',
      tag: tag,
      body: body,
      footerLeft: footerLeft,
      footerRight: footerRight,
      dimmed: dimmed,
    );
  }
}

class _EmptyHostsBody extends StatelessWidget {
  const _EmptyHostsBody();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Text('NO HOST DATA', style: TextStyle(color: t.muted)),
    );
  }
}

class _VitalsBody extends StatelessWidget {
  final HostVitals vitals;
  const _VitalsBody({required this.vitals});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KvRow.text('Server', vitals.slug),
        KvRow(
          label: 'Status',
          value: Text(
            '${hostStatusGlyph(vitals.status)} ${vitals.status.toUpperCase()}',
            style: TextStyle(color: t.ink),
          ),
        ),
        KvRow.text('Procs', vitals.processCount?.toString() ?? '—'),
        KvRow.text('Sampled', _time(vitals.sampledAt)),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const tileSpacing = 1.0;
              const tileCount = 4; // CPU, Mem, Disk, Network
              // Picking columns purely from width/151 (a "comfortable" tile
              // width) meant a moderately narrower window could drop from 4
              // columns to 2 well before it was actually necessary — and
              // fewer columns means more ROWS for the same 4 tiles, which
              // starves every row's height even though total available
              // height didn't change. Preferring the highest column count
              // (fewest rows) down to a much narrower per-tile minimum keeps
              // all 4 tiles in a single row for most realistic widths, so
              // row height stays governed by the panel's actual height, not
              // by how narrow the window happens to be.
              const minTileWidth = 70.0;
              var columns = 1;
              for (final c in [4, 3, 2, 1]) {
                if (constraints.maxWidth / c >= minTileWidth) {
                  columns = c;
                  break;
                }
              }
              final rows = (tileCount / columns).ceil();
              final tileWidth = constraints.maxWidth / columns;
              final rowBudget =
                  (constraints.maxHeight - (rows - 1) * tileSpacing) / rows;
              // Never forced above rowBudget: doing so (an earlier version
              // of this fix used clamp(90.0, 112.0)) makes the grid's total
              // content height exceed the space it's actually given, which
              // silently clips the trailing row instead of shrinking to fit
              // — exactly the bug this whole computation exists to avoid.
              // StatTile's own FittedBox is the safety net for genuinely
              // short panels (e.g. two Vitals panels stacked); with columns
              // maximized above, that case is now rare.
              final tileHeight = rowBudget.clamp(1.0, 112.0);
              final gridHeight = rows * tileHeight + (rows - 1) * tileSpacing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: gridHeight,
                    child: GridView.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: tileSpacing,
                      crossAxisSpacing: tileSpacing,
                      childAspectRatio: tileWidth / tileHeight,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _percentTile(
                          label: 'CPU',
                          gauge: vitals.cpu,
                          sub: (g) =>
                              '${g.used.toStringAsFixed(1)} / ${_fixed(g.allowed)} ${g.unit}',
                        ),
                        _percentTile(
                          label: 'Mem',
                          gauge: vitals.memory,
                          sub: (g) =>
                              '${(g.used / 1024).toStringAsFixed(1)} / ${_fixed(g.allowed != null ? g.allowed! / 1024 : null)} GB',
                        ),
                        _percentTile(
                          label: 'Disk',
                          gauge: vitals.disk,
                          sub: (g) =>
                              '${(g.used / 1024).toStringAsFixed(1)} / ${_fixed(g.allowed != null ? g.allowed! / 1024 : null)} GB',
                        ),
                        _networkTile(vitals.network),
                      ],
                    ),
                  ),
                  // A Stack+Positioned dot anchored to this section's own
                  // bottom-right corner painted over the grid whenever the
                  // grid's real content height reached that corner (any
                  // time rows > 1, or a tall single row) — the dot doesn't
                  // know the grid's layout, it just paints on top of
                  // whatever is there. Giving the dot its own Expanded
                  // sibling below the (now content-sized, not
                  // stretched) grid means it only ever occupies genuinely
                  // leftover space and can't overlap a live tile.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: HalftoneDot(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Network shows the scaled absolute used/allowed, not a percent, so it
  // needs its own null-allowed fallback rather than sharing _percentTile.
  // A gauge with `used` but no `allowed` (a genuinely uncapped resource) is
  // treated the same as an absent gauge for now: showing "used, no cap" in
  // a tile built for a used/allowed pair is a display this phase doesn't
  // need to design yet, since no current or Phase 2 provider reports one.
  StatTile _networkTile(Gauge? network) {
    if (network == null || network.allowed == null) {
      return const StatTile.unavailable(label: 'Network');
    }
    final scale = _networkScale(network.allowed!);
    final total = network.used / scale.value;
    final allowed = network.allowed! / scale.value;
    return StatTile(
      number: total.toStringAsFixed(1),
      unit: ' ${scale.unit}',
      label: 'Network',
      sub:
          '${total.toStringAsFixed(1)} / ${allowed.toStringAsFixed(1)} ${scale.unit} · MTD',
      level: network.level,
    );
  }

  StatTile _percentTile({
    required String label,
    required Gauge? gauge,
    required String Function(Gauge gauge) sub,
  }) {
    if (gauge == null || gauge.percentUsed == null) {
      return StatTile.unavailable(label: label);
    }
    return StatTile(
      number: gauge.percentUsed!.round().toString(),
      unit: '%',
      label: label,
      sub: sub(gauge),
      level: gauge.level,
    );
  }
}

String _fixed(double? value) => value == null ? '—' : value.toStringAsFixed(1);
