import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../features/vps/domain/host_vitals.dart';

class StatTile extends StatelessWidget {
  final String number;
  final String unit;
  final String label;
  final String sub;
  final UsageLevel level;

  const StatTile({
    super.key,
    required this.number,
    required this.unit,
    required this.label,
    required this.sub,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final crit = level == UsageLevel.crit;
    final warn = level == UsageLevel.warn;
    final fg = crit ? t.paper : t.ink;
    final labelText = switch (level) {
      UsageLevel.crit => '■ ${label.toUpperCase()} · CRIT',
      UsageLevel.warn => '! ${label.toUpperCase()}',
      UsageLevel.ok => label.toUpperCase(),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: crit ? t.ink : t.paper,
        border: warn ? Border(top: BorderSide(color: t.lineStrong, width: 2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: number,
              style: AppTypography.tileNum.copyWith(color: fg),
              children: [
                TextSpan(
                  text: unit,
                  style: AppTypography.tileUnit.copyWith(color: crit ? fg.withValues(alpha: 0.7) : t.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            labelText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.tileLabel.copyWith(color: fg, fontWeight: crit ? FontWeight.w700 : FontWeight.normal),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.tileSub.copyWith(color: crit ? fg.withValues(alpha: 0.72) : t.muted),
          ),
        ],
      ),
    );
  }
}
