import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme/tokens.dart';

class GrainOverlay extends StatefulWidget {
  const GrainOverlay({super.key});

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await rootBundle.load('assets/images/grain-180.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
    } else {
      frame.image.dispose();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    final tokens = context.tokens;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GrainPainter(image, tokens.grainBlend, tokens.grainOpacity, dpr),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final ui.Image image;
  final BlendMode blend;
  final double opacity;
  final double devicePixelRatio;

  _GrainPainter(this.image, this.blend, this.opacity, this.devicePixelRatio);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = devicePixelRatio <= 0 ? 1.0 : 1.0 / devicePixelRatio;
    final shader = ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().scaledByDouble(scale, scale, 1, 1).storage,
    );
    final paint = Paint()
      ..shader = shader
      ..blendMode = blend
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.blend != blend || oldDelegate.opacity != opacity;
}
