import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/providers/registry_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/err_block.dart';
import '../../../shared/widgets/source_error_text.dart';
import '../../dashboard/panel_frame.dart';
import '../domain/monitor_status.dart';
import 'monitor_row.dart';
import 'monitor_skeleton.dart';
import 'uptime_provider.dart';

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

class MonitorPanel extends ConsumerWidget {
  final String sourceId;
  const MonitorPanel({super.key, required this.sourceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(uptimeProvider(sourceId));
    final config = ref.watch(appConfigProvider);
    final pollSeconds = config.pollInterval.inSeconds;
    final entry = config.uptime.firstWhere((u) => u.id == sourceId);
    final providerTag =
        ref.watch(providerRegistryProvider).uptimeSpec(entry.provider)?.tag ??
        entry.provider.toUpperCase();

    final hasValue = async.hasValue;
    final hasError = async.hasError;
    final isLoading = async.isLoading;

    final String tag;
    final String footerLeft;
    final String footerRight;
    final Widget body;
    var dimmed = false;

    if (isLoading && !hasValue) {
      tag = '—';
      footerLeft = 'Loading';
      footerRight = '—';
      body = const MonitorSkeleton();
    } else if (hasError && !hasValue) {
      tag = '—';
      footerLeft = 'Error · ${_time(clock.now())}';
      footerRight = 'Retry ${pollSeconds}s';
      body = ErrBlock(
        message: sourceErrorMessage(async.error, tag: providerTag),
        hint: 'Retry in ${pollSeconds}s · ⌘R to retry now',
      );
    } else {
      final sample = async.requireValue;
      final monitors = sample.value;
      final downCount = monitors
          .where((m) => m.state == MonitorState.down)
          .length;
      tag = monitors.length.toString().padLeft(2, '0');
      footerRight =
          '${monitors.length.toString().padLeft(2, '0')} monitors · ${downCount.toString().padLeft(2, '0')} down';

      if (isLoading) {
        footerLeft = 'Refreshing';
      } else if (hasError) {
        dimmed = true;
        footerLeft =
            'Stale · Last ok ${_time(sample.fetchedAt)} · ${sourceErrorKind(async.error)}';
      } else {
        footerLeft = 'Fetched ${_time(sample.fetchedAt)}';
      }
      final t = context.tokens;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonitorColumnHeader(line: t.line, faint: t.faint),
          Expanded(
            child: ListView.builder(
              itemCount: monitors.length,
              itemBuilder: (context, i) => MonitorRow(monitor: monitors[i]),
            ),
          ),
        ],
      );
    }

    return PanelFrame(
      title: 'Monitors',
      tag: tag,
      body: body,
      footerLeft: footerLeft,
      footerRight: footerRight,
      dimmed: dimmed,
    );
  }
}
