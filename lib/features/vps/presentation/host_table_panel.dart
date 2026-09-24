import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../domain/host_vitals.dart';
import 'host_status_glyph.dart';

const hostTableColumnWidths = [22.0, 52.0, 52.0, 52.0];

/// A source that yields several hosts (a fleet-wide Prometheus exporter,
/// Phase 2) renders as a compact row-per-host table instead of exploding
/// into one detail tile per host.
class HostTablePanel extends StatelessWidget {
  final List<HostVitals> hosts;
  const HostTablePanel({super.key, required this.hosts});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HostTableHeader(line: t.line, faint: t.faint),
        Expanded(
          child: ListView.builder(
            physics: const ClampingScrollPhysics(),
            itemCount: hosts.length,
            itemBuilder: (context, i) => _HostRow(host: hosts[i]),
          ),
        ),
      ],
    );
  }
}

class _HostTableHeader extends StatelessWidget {
  final Color line;
  final Color faint;
  const _HostTableHeader({required this.line, required this.faint});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.colHeader.copyWith(color: faint);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(width: hostTableColumnWidths[0]),
          Expanded(child: Text('NAME', style: style)),
          SizedBox(
            width: hostTableColumnWidths[1],
            child: Text('CPU', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: hostTableColumnWidths[2],
            child: Text('MEM', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: hostTableColumnWidths[3],
            child: Text('DISK', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _HostRow extends StatelessWidget {
  final HostVitals host;
  const _HostRow({required this.host});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rowStyle = AppTypography.row.copyWith(color: t.ink);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.lineSoft, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: hostTableColumnWidths[0],
            child: Text(
              hostStatusGlyph(host.status),
              style: AppTypography.glyph.copyWith(color: t.ink),
            ),
          ),
          Expanded(
            child: Text(
              host.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: rowStyle,
            ),
          ),
          SizedBox(
            width: hostTableColumnWidths[1],
            child: Text(
              '${host.cpu.percentUsed.round()}%',
              textAlign: TextAlign.right,
              style: rowStyle,
            ),
          ),
          SizedBox(
            width: hostTableColumnWidths[2],
            child: Text(
              '${host.memory.percentUsed.round()}%',
              textAlign: TextAlign.right,
              style: rowStyle,
            ),
          ),
          SizedBox(
            width: hostTableColumnWidths[3],
            child: Text(
              '${host.disk.percentUsed.round()}%',
              textAlign: TextAlign.right,
              style: rowStyle,
            ),
          ),
        ],
      ),
    );
  }
}
