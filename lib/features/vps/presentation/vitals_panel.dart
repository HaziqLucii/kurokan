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
import '../../../shared/widgets/status_glyph.dart';
import '../../dashboard/panel_frame.dart';
import '../domain/host_vitals.dart';
import 'hosts_provider.dart';
import 'vitals_skeleton.dart';

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

String _statusGlyphFor(String status) => switch (status) {
  'running' => StatusGlyphs.up,
  'stopped' || 'suspended' => StatusGlyphs.muted,
  'error' => StatusGlyphs.down,
  _ =>
    StatusGlyphs
        .pending, // provisioning/starting/rebooting/stopping/reinstalling
};

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
      // Phase 1.4 scope: every provider today (webdock, demo) always
      // yields exactly one host. Phase 1.5 adds a compact host table for a
      // source that yields several (Prometheus etc, Phase 2). An empty
      // list isn't reachable by any current provider but is handled
      // gracefully rather than crashing on `.first`.
      body = hosts.isEmpty
          ? const _EmptyHostsBody()
          : _VitalsBody(vitals: hosts.first);
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
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KvRow.text('Server', vitals.slug),
            KvRow(
              label: 'Status',
              value: Text(
                '${_statusGlyphFor(vitals.status)} ${vitals.status.toUpperCase()}',
                style: TextStyle(color: t.ink),
              ),
            ),
            KvRow.text('Procs', vitals.processCount?.toString() ?? '—'),
            KvRow.text('Sampled', _time(vitals.sampledAt)),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 151).floor().clamp(
                    1,
                    8,
                  );
                  return GridView.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 1,
                    childAspectRatio: (constraints.maxWidth / columns) / 112,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatTile(
                        number: vitals.cpu.percentUsed.round().toString(),
                        unit: '%',
                        label: 'CPU',
                        sub:
                            '${vitals.cpu.used.toStringAsFixed(1)} / ${vitals.cpu.allowed.toStringAsFixed(1)} ${vitals.cpu.unit}',
                        level: vitals.cpu.level,
                      ),
                      StatTile(
                        number: vitals.memory.percentUsed.round().toString(),
                        unit: '%',
                        label: 'Mem',
                        sub:
                            '${(vitals.memory.used / 1024).toStringAsFixed(1)} / ${(vitals.memory.allowed / 1024).toStringAsFixed(1)} GB',
                        level: vitals.memory.level,
                      ),
                      StatTile(
                        number: vitals.disk.percentUsed.round().toString(),
                        unit: '%',
                        label: 'Disk',
                        sub:
                            '${(vitals.disk.used / 1024).toStringAsFixed(1)} / ${(vitals.disk.allowed / 1024).toStringAsFixed(1)} GB',
                        level: vitals.disk.level,
                      ),
                      _networkTile(vitals.network),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        const Positioned(right: 0, bottom: 6, child: HalftoneDot()),
      ],
    );
  }

  StatTile _networkTile(Gauge network) {
    final scale = _networkScale(network.allowed);
    final total = network.used / scale.value;
    final allowed = network.allowed / scale.value;
    return StatTile(
      number: total.toStringAsFixed(1),
      unit: ' ${scale.unit}',
      label: 'Network',
      sub:
          '${total.toStringAsFixed(1)} / ${allowed.toStringAsFixed(1)} ${scale.unit} · MTD',
      level: network.level,
    );
  }
}
