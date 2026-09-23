import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/fetch_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/err_block.dart';
import '../../dashboard/panel_frame.dart';
import '../domain/monitor_status.dart';
import 'monitor_row.dart';
import 'monitor_skeleton.dart';
import 'monitors_provider.dart';

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
      NetworkError e => 'NETWORK · ${e.detail} · CHECK kuma.url',
      AuthError e => 'AUTH · ${e.status} FROM KUMA · CHECK kuma.apiKey',
      HttpError e => 'HTTP · ${e.status} FROM KUMA',
      ParseError e => 'PARSE · ${e.detail}',
      TimeoutError _ => 'TIMEOUT · 10S',
      _ => 'UNKNOWN ERROR',
    };

class MonitorPanel extends ConsumerWidget {
  const MonitorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monitorsProvider);
    final pollSeconds = ref.watch(appConfigProvider).pollInterval.inSeconds;

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
        message: _errorMessage(async.error),
        hint: 'Retry in ${pollSeconds}s · ⌘R to retry now',
      );
    } else {
      final sample = async.requireValue;
      final monitors = sample.value;
      final downCount = monitors.where((m) => m.state == MonitorState.down).length;
      tag = monitors.length.toString().padLeft(2, '0');
      footerRight =
          '${monitors.length.toString().padLeft(2, '0')} monitors · ${downCount.toString().padLeft(2, '0')} down';

      if (isLoading) {
        footerLeft = 'Refreshing';
      } else if (hasError) {
        dimmed = true;
        footerLeft = 'Stale · Last ok ${_time(sample.fetchedAt)} · ${_errorKind(async.error)}';
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
