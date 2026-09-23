import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../domain/monitor_status.dart';
import 'monitor_skeleton.dart' show monitorRowColumnWidths;

String _glyphFor(MonitorState state) => switch (state) {
  MonitorState.up => '●',
  MonitorState.pending => '◐',
  MonitorState.maintenance => '○',
  MonitorState.down => '■',
};

String _uptimeText(double? ratio) =>
    ratio == null ? '—' : '${(ratio * 100).toStringAsFixed(2)}%';

String? _certText(MonitorStatus monitor) {
  final days = monitor.certDaysRemaining;
  if (days == null) return null;
  final warn = days < 14 || monitor.certValid == false;
  return '${warn ? '!' : ''}${days}D';
}

class MonitorRow extends StatelessWidget {
  final MonitorStatus monitor;

  const MonitorRow({super.key, required this.monitor});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (monitor.state == MonitorState.down) {
      return _DownRow(monitor: monitor, ink: t.ink, paper: t.paper);
    }

    final glyphColor = monitor.state == MonitorState.up
        ? statusUpColor
        : t.muted;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.lineSoft, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: monitorRowColumnWidths[0],
            child: Text(
              _glyphFor(monitor.state),
              style: AppTypography.glyph.copyWith(color: glyphColor),
            ),
          ),
          Expanded(
            child: Text(
              monitor.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTypography.row.copyWith(color: t.ink),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[1],
            child: Text(
              monitor.type.toUpperCase(),
              style: AppTypography.rowType.copyWith(color: t.faint),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[2],
            child: _RespCell(monitor: monitor, ink: t.ink, muted: t.muted),
          ),
          SizedBox(
            width: monitorRowColumnWidths[3],
            child: Text(
              _uptimeText(monitor.uptime24h),
              textAlign: TextAlign.right,
              style: AppTypography.row.copyWith(color: t.ink),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[4],
            child: _CertCell(monitor: monitor, muted: t.muted),
          ),
        ],
      ),
    );
  }
}

class _RespCell extends StatelessWidget {
  final MonitorStatus monitor;
  final Color ink;
  final Color muted;

  const _RespCell({
    required this.monitor,
    required this.ink,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    if (monitor.state == MonitorState.pending) {
      return Text(
        'PEND',
        textAlign: TextAlign.right,
        style: AppTypography.rowType.copyWith(color: muted),
      );
    }
    if (monitor.state == MonitorState.maintenance) {
      return Text(
        'MAINT',
        textAlign: TextAlign.right,
        style: AppTypography.rowType.copyWith(color: muted),
      );
    }
    final rt = monitor.responseTime;
    return Text(
      rt == null ? '—' : '${rt.inMilliseconds}ms',
      textAlign: TextAlign.right,
      style: AppTypography.row.copyWith(color: ink),
    );
  }
}

class _CertCell extends StatelessWidget {
  final MonitorStatus monitor;
  final Color muted;

  const _CertCell({required this.monitor, required this.muted});

  @override
  Widget build(BuildContext context) {
    final text = _certText(monitor);
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppTypography.rowCert.copyWith(color: muted),
    );
  }
}

class _DownRow extends StatelessWidget {
  final MonitorStatus monitor;
  final Color ink;
  final Color paper;

  const _DownRow({
    required this.monitor,
    required this.ink,
    required this.paper,
  });

  @override
  Widget build(BuildContext context) {
    final certText = _certText(monitor);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: ink,
      child: Row(
        children: [
          SizedBox(
            width: monitorRowColumnWidths[0],
            child: Text(
              '■',
              style: AppTypography.glyphDown.copyWith(color: statusDownColor),
            ),
          ),
          Expanded(
            child: Text(
              monitor.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTypography.row.copyWith(
                color: paper,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[1],
            child: Text(
              monitor.type.toUpperCase(),
              style: AppTypography.rowType.copyWith(color: paper),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[2],
            child: Text(
              'DOWN',
              textAlign: TextAlign.right,
              style: AppTypography.downLabel.copyWith(color: paper),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[3],
            child: Text(
              _uptimeText(monitor.uptime24h),
              textAlign: TextAlign.right,
              style: AppTypography.row.copyWith(color: paper),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[4],
            child: certText == null
                ? const SizedBox.shrink()
                : Text(
                    certText,
                    textAlign: TextAlign.right,
                    style: AppTypography.rowCert.copyWith(color: paper),
                  ),
          ),
        ],
      ),
    );
  }
}
