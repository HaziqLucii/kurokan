import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

enum DossierButtonVisual { idle, active, disabled }

class DossierButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DossierButtonVisual visual;

  const DossierButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.visual = DossierButtonVisual.idle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = visual == DossierButtonVisual.disabled;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: disabled ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: visual == DossierButtonVisual.active
                  ? t.tint
                  : Colors.transparent,
              border: Border.all(color: t.lineStrong, width: 1),
            ),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.button.copyWith(color: t.ink),
            ),
          ),
        ),
      ),
    );
  }
}
