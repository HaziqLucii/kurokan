import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'hairline.dart';

class PanelTitle extends StatelessWidget {
  final String title;
  final String tag;

  const PanelTitle({super.key, required this.title, required this.tag});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: AppTypography.panelTitle.copyWith(color: t.ink)),
          const SizedBox(width: 12),
          Text(tag.toUpperCase(), style: AppTypography.panelTag.copyWith(color: t.faint)),
          const SizedBox(width: 12),
          Expanded(child: Hairline(color: t.line)),
        ],
      ),
    );
  }
}
