import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/fetch_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/err_block.dart';
import '../../../shared/widgets/halftone_dot.dart';
import '../../../shared/widgets/kv_row.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../../shared/widgets/status_glyph.dart';
import '../../dashboard/panel_frame.dart';
import '../domain/host_vitals.dart';
import 'vitals_provider.dart';
import 'vitals_skeleton.dart';

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

String _errorKind(Object? error) => switch (error) {
  NetworkError _ => 'NETWORK',
  AuthError _ => 'AUTH',
  HttpError _ => 'HTTP',
  ParseError _ => 'PARSE',
  TimeoutError _ => 'TIMEOUT',
  _ => 'ERROR',
};

String _errorMessage(Object? error) => switch (error) {
  NetworkError e => 'NETWORK · ${e.detail} · CHECK webdock.slug',
  AuthError e => 'AUTH · ${e.status} FROM WEBDOCK · CHECK webdock.apiToken',
  HttpError e => 'HTTP · ${e.status} FROM WEBDOCK',
  ParseError e => 'PARSE · ${e.detail}',
  TimeoutError _ => 'TIMEOUT · 10S',
  _ => 'UNKNOWN ERROR',
};

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
  const VitalsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vitalsProvider);
    final pollSeconds = ref.watch(appConfigProvider).pollInterval.inSeconds;

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
        message: _errorMessage(async.error),
        hint: 'Retry in ${pollSeconds}s',
        padding: const EdgeInsets.symmetric(vertical: 16),
      );
    } else {
      final sample = async.requireValue;
      final vitals = sample.value;
      footerRight = 'Poll ${pollSeconds}s';

      if (isLoading) {
        footerLeft = 'Refreshing';
      } else if (hasError) {
        dimmed = true;
        footerLeft =
            'Stale · Last ok ${_time(sample.fetchedAt)} · ${_errorKind(async.error)}';
      } else {
        footerLeft = 'Fetched ${_time(sample.fetchedAt)}';
      }
      body = _VitalsBody(vitals: vitals);
    }

    return PanelFrame(
      title: 'Vitals',
      tag: 'Webdock',
      body: body,
      footerLeft: footerLeft,
      footerRight: footerRight,
      dimmed: dimmed,
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
