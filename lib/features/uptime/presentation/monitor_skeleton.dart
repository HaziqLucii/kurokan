import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

const monitorRowColumnWidths = [22.0, 70.0, 64.0, 72.0, 44.0];

const _skeletonNameFractions = [0.46, 0.32, 0.58, 0.40, 0.28, 0.52, 0.36, 0.44];

class MonitorSkeleton extends StatelessWidget {
  const MonitorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonitorColumnHeader(line: t.line, faint: t.faint),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            children: [
              for (final fraction in _skeletonNameFractions)
                _SkeletonRow(nameFraction: fraction, lineSoft: t.lineSoft, tint: t.tint, tint2: t.tint2),
            ],
          ),
        ),
      ],
    );
  }
}

class MonitorColumnHeader extends StatelessWidget {
  final Color line;
  final Color faint;
  const MonitorColumnHeader({super.key, required this.line, required this.faint});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.colHeader.copyWith(color: faint);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line, width: 1))),
      child: Row(
        children: [
          SizedBox(width: monitorRowColumnWidths[0]),
          Expanded(child: Text('NAME', style: style)),
          SizedBox(width: monitorRowColumnWidths[1], child: Text('TYPE', style: style)),
          SizedBox(width: monitorRowColumnWidths[2], child: Text('RESP', textAlign: TextAlign.right, style: style)),
          SizedBox(width: monitorRowColumnWidths[3], child: Text('24H', textAlign: TextAlign.right, style: style)),
          SizedBox(width: monitorRowColumnWidths[4], child: Text('CERT', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final double nameFraction;
  final Color lineSoft;
  final Color tint;
  final Color tint2;

  const _SkeletonRow({
    required this.nameFraction,
    required this.lineSoft,
    required this.tint,
    required this.tint2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lineSoft, width: 1))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: monitorRowColumnWidths[0], child: Container(width: 7, height: 7, color: tint2)),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: nameFraction,
              child: Container(height: 7, color: tint2),
            ),
          ),
          SizedBox(
            width: monitorRowColumnWidths[1],
            child: Align(alignment: Alignment.centerLeft, child: Container(width: 34, height: 7, color: tint)),
          ),
          SizedBox(
            width: monitorRowColumnWidths[2],
            child: Align(alignment: Alignment.centerRight, child: Container(width: 36, height: 7, color: tint2)),
          ),
          SizedBox(
            width: monitorRowColumnWidths[3],
            child: Align(alignment: Alignment.centerRight, child: Container(width: 48, height: 7, color: tint2)),
          ),
          SizedBox(
            width: monitorRowColumnWidths[4],
            child: Align(alignment: Alignment.centerRight, child: Container(width: 22, height: 7, color: tint)),
          ),
        ],
      ),
    );
  }
}
