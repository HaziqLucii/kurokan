import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/halftone_dot.dart';

const _skeletonKvValueWidths = [110.0, 74.0, 92.0, 100.0];

class VitalsSkeleton extends StatelessWidget {
  const VitalsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final valueWidth in _skeletonKvValueWidths)
              _SkeletonKvRow(valueWidth: valueWidth, lineSoft: t.lineSoft, tint: t.tint, tint2: t.tint2),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 151).floor().clamp(1, 8);
                  return GridView.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 1,
                    childAspectRatio: (constraints.maxWidth / columns) / 112,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(
                      4,
                      (_) => _SkeletonTile(border: t.lineSoft, tint: t.tint, tint2: t.tint2, paper: t.paper),
                    ),
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
}

class _SkeletonKvRow extends StatelessWidget {
  final double valueWidth;
  final Color lineSoft;
  final Color tint;
  final Color tint2;

  const _SkeletonKvRow({
    required this.valueWidth,
    required this.lineSoft,
    required this.tint,
    required this.tint2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lineSoft, width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 52, height: 7, color: tint),
          Container(width: valueWidth, height: 7, color: tint2),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final Color border;
  final Color tint;
  final Color tint2;
  final Color paper;

  const _SkeletonTile({required this.border, required this.tint, required this.tint2, required this.paper});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: paper,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 64, height: 38, color: tint),
          Container(width: 40, height: 7, color: tint2),
          Container(width: 78, height: 7, color: tint),
        ],
      ),
    );
  }
}
