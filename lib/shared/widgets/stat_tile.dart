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

  /// For a gauge a provider genuinely can't supply (not one that's merely
  /// unbounded): renders `—` instead of a percent.
  const StatTile.unavailable({super.key, required this.label, this.sub = '—'})
    : number = '—',
      unit = '',
      level = UsageLevel.ok;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final crit = level == UsageLevel.crit;
    final warn = level == UsageLevel.warn;
    final fg = crit ? t.paper : t.ink;
    final numberColor = switch (level) {
      UsageLevel.crit => statusDownColor,
      UsageLevel.warn => statusWarnColor,
      UsageLevel.ok => fg,
    };
    final labelText = switch (level) {
      UsageLevel.crit => '■ ${label.toUpperCase()} · CRIT',
      UsageLevel.warn => '! ${label.toUpperCase()}',
      UsageLevel.ok => label.toUpperCase(),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: crit ? t.ink : t.paper,
        border: warn
            ? Border(top: BorderSide(color: statusWarnColor, width: 2))
            : null,
      ),
      // A tile given less height than its content naturally needs (two
      // Vitals panels sharing a narrow column, a narrow window forcing
      // fewer grid columns and more rows) scales the whole thing down
      // uniformly instead of overflowing; a tile with room to spare
      // renders at its normal size (scaleDown never enlarges).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                text: number,
                style: AppTypography.tileNum.copyWith(color: numberColor),
                children: [
                  TextSpan(
                    text: unit,
                    style: AppTypography.tileUnit.copyWith(
                      color: crit ? fg.withValues(alpha: 0.7) : t.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              labelText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.tileLabel.copyWith(
                color: fg,
                fontWeight: crit ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.tileSub.copyWith(
                color: crit ? fg.withValues(alpha: 0.72) : t.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
