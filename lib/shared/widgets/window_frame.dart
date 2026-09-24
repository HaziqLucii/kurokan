import 'package:flutter/material.dart';

import '../../core/platform/platform_info.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'grain_overlay.dart';

class WindowFrame extends StatelessWidget {
  final String marginMetaText;
  final Widget Function(BuildContext context, double containerWidth)
  contentBuilder;

  const WindowFrame({
    super.key,
    required this.marginMetaText,
    required this.contentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Column(
          children: [
            if (PlatformInfo.isMacOS)
              _ChromeStrip(edge: t.edge, lineSoft: t.lineSoft),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final watermarkSize = (width * 0.30).clamp(180.0, 440.0);
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(60, 22, 40, 22),
                          child: contentBuilder(context, width),
                        ),
                      ),
                      Positioned(
                        right: -0.015 * width,
                        bottom: -0.10 * height,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.035,
                            child: Text(
                              '監',
                              style: AppTypography.watermark.copyWith(
                                fontSize: watermarkSize,
                                color: t.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 22,
                        bottom: 22,
                        child: IgnorePointer(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              marginMetaText.toUpperCase(),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: AppTypography.marginMeta.copyWith(
                                color: t.faint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        const GrainOverlay(),
      ],
    );
  }
}

class _ChromeStrip extends StatelessWidget {
  final Color edge;
  final Color lineSoft;
  const _ChromeStrip({required this.edge, required this.lineSoft});

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    decoration: BoxDecoration(
      color: edge,
      border: Border(bottom: BorderSide(color: lineSoft, width: 1)),
    ),
  );
}
