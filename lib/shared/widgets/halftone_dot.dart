import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

class HalftoneDot extends StatelessWidget {
  const HalftoneDot({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = context.tokens.ink;
    return RepaintBoundary(
      child: SizedBox(
        width: 84,
        height: 84,
        child: CustomPaint(painter: _HalftonePainter(ink)),
      ),
    );
  }
}

class _HalftonePainter extends CustomPainter {
  static const _pitch = 4.0;
  static const _dotRadius = 0.9;
  static const _centerFraction = 0.34;

  final Color ink;
  _HalftonePainter(this.ink);

  double _alphaAt(double fraction) {
    if (fraction <= 0) return 1;
    if (fraction <= 0.28) return 1 - (fraction / 0.28) * 0.25;
    if (fraction <= 0.52) return 0.75 - ((fraction - 0.28) / 0.24) * 0.45;
    if (fraction <= 0.70) return 0.3 - ((fraction - 0.52) / 0.18) * 0.3;
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * _centerFraction,
      size.height * _centerFraction,
    );
    final paint = Paint();
    for (double y = _pitch / 2; y < size.height; y += _pitch) {
      for (double x = _pitch / 2; x < size.width; x += _pitch) {
        final fraction = (Offset(x, y) - center).distance / size.width;
        final alpha = (_alphaAt(fraction) * 0.55).clamp(0.0, 1.0);
        if (alpha <= 0) continue;
        paint.color = ink.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter oldDelegate) =>
      oldDelegate.ink != ink;
}
