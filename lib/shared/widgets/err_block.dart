import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

class ErrBlock extends StatelessWidget {
  final String message;
  final String hint;
  final EdgeInsets padding;

  const ErrBlock({
    super.key,
    required this.message,
    required this.hint,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                color: t.ink,
                child: Text(
                  'ERR',
                  style: AppTypography.errChip.copyWith(color: t.paper),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.errMsg.copyWith(color: t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(hint, style: AppTypography.errHint.copyWith(color: t.faint)),
        ],
      ),
    );
  }
}
