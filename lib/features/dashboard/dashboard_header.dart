import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/dossier_button.dart';

class DashboardHeader extends StatelessWidget {
  final double containerWidth;
  final String lastText;
  final String refreshLabel;
  final DossierButtonVisual refreshVisual;
  final VoidCallback? onRefresh;
  final VoidCallback? onSettings;

  const DashboardHeader({
    super.key,
    required this.containerWidth,
    required this.lastText,
    required this.refreshLabel,
    required this.refreshVisual,
    required this.onRefresh,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wordmarkSize = (containerWidth * 0.09).clamp(48.0, 96.0);
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'kurokan',
              style: AppTypography.wordmarkBase.copyWith(
                fontSize: wordmarkSize,
                letterSpacing: wordmarkSize * -0.03,
                color: t.ink,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'LAST $lastText',
                  style: AppTypography.lastLabel.copyWith(color: t.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onSettings != null) ...[
                      DossierButton(label: 'Settings', onPressed: onSettings),
                      const SizedBox(width: 8),
                    ],
                    DossierButton(
                      label: refreshLabel,
                      onPressed: onRefresh,
                      visual: refreshVisual,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
