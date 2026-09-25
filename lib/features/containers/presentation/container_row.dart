import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/status_glyph.dart';
import '../domain/container_status.dart';

const containerRowColumnWidths = [22.0, 96.0, 44.0, 52.0, 50.0, 56.0];

String _glyphFor(ContainerStatus c) {
  if (c.state == ContainerState.running) {
    return switch (c.health) {
      HealthState.unhealthy => StatusGlyphs.down,
      HealthState.starting => StatusGlyphs.pending,
      HealthState.healthy || HealthState.none => StatusGlyphs.up,
    };
  }
  return switch (c.state) {
    ContainerState.exited || ContainerState.dead => StatusGlyphs.down,
    ContainerState.paused ||
    ContainerState.restarting ||
    ContainerState.created => StatusGlyphs.muted,
    _ => StatusGlyphs.pending,
  };
}

String _uptimeText(DateTime? startedAt, DateTime now) {
  if (startedAt == null) return '—';
  final elapsed = now.difference(startedAt);
  if (elapsed.inDays > 0) return '${elapsed.inDays}D';
  if (elapsed.inHours > 0) return '${elapsed.inHours}H';
  if (elapsed.inMinutes > 0) return '${elapsed.inMinutes}M';
  return '${elapsed.inSeconds}S';
}

String _cpuText(double? percent) =>
    percent == null ? '—' : '${percent.round()}%';

String _memText(int? usedBytes) =>
    usedBytes == null ? '—' : '${(usedBytes / (1024 * 1024)).round()}MB';

class ContainerRow extends StatelessWidget {
  final ContainerStatus container;
  final DateTime now;

  const ContainerRow({super.key, required this.container, required this.now});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final glyphColor = container.state == ContainerState.running
        ? (container.health == HealthState.unhealthy
              ? statusDownColor
              : statusUpColor)
        : t.muted;
    final restartColor = container.restartCount > 0 ? statusWarnColor : t.faint;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.lineSoft, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: containerRowColumnWidths[0],
            child: Text(
              _glyphFor(container),
              style: AppTypography.glyph.copyWith(color: glyphColor),
            ),
          ),
          Expanded(
            child: Text(
              container.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTypography.row.copyWith(color: t.ink),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[1],
            child: Text(
              container.image,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: AppTypography.rowType.copyWith(color: t.faint),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[2],
            child: Text(
              _uptimeText(container.startedAt, now),
              textAlign: TextAlign.right,
              style: AppTypography.row.copyWith(color: t.ink),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[3],
            child: Text(
              '${container.restartCount}',
              textAlign: TextAlign.right,
              style: AppTypography.row.copyWith(color: restartColor),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[4],
            child: Text(
              _cpuText(container.cpuPercent),
              textAlign: TextAlign.right,
              style: AppTypography.row.copyWith(color: t.ink),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[5],
            child: Text(
              _memText(container.memUsed),
              textAlign: TextAlign.right,
              style: AppTypography.row.copyWith(color: t.ink),
            ),
          ),
        ],
      ),
    );
  }
}
