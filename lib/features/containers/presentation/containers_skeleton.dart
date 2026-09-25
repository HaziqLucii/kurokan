import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import 'container_row.dart';

const _skeletonNameFractions = [0.5, 0.34, 0.44, 0.28];

class ContainersSkeleton extends StatelessWidget {
  const ContainersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContainersColumnHeader(line: t.line, faint: t.faint),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            children: [
              for (final fraction in _skeletonNameFractions)
                _SkeletonRow(
                  nameFraction: fraction,
                  lineSoft: t.lineSoft,
                  tint: t.tint,
                  tint2: t.tint2,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ContainersColumnHeader extends StatelessWidget {
  final Color line;
  final Color faint;
  const ContainersColumnHeader({
    super.key,
    required this.line,
    required this.faint,
  });

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
          SizedBox(width: containerRowColumnWidths[0]),
          Expanded(
            child: Text(
              'NAME',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[1],
            child: Text(
              'IMAGE',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[2],
            child: Text(
              'UP',
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[3],
            child: Text(
              'RST',
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[4],
            child: Text(
              'CPU',
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[5],
            child: Text(
              'MEM',
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineSoft, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: containerRowColumnWidths[0],
            child: Container(width: 7, height: 7, color: tint2),
          ),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: nameFraction,
              child: Container(height: 7, color: tint2),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[1],
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 60, height: 7, color: tint),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[2],
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 24, height: 7, color: tint2),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[3],
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 14, height: 7, color: tint),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[4],
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 22, height: 7, color: tint2),
            ),
          ),
          SizedBox(
            width: containerRowColumnWidths[5],
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 30, height: 7, color: tint),
            ),
          ),
        ],
      ),
    );
  }
}
