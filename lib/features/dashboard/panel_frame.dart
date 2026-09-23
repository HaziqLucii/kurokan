import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/panel_title.dart';

class PanelFrame extends StatelessWidget {
  final String title;
  final String tag;
  final Widget body;
  final String footerLeft;
  final String footerRight;
  final bool dimmed;

  const PanelFrame({
    super.key,
    required this.title,
    required this.tag,
    required this.body,
    required this.footerLeft,
    required this.footerRight,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelTitle(title: title, tag: tag),
        Expanded(
          child: ClipRect(
            child: dimmed ? Opacity(opacity: 0.86, child: body) : body,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: 1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  footerLeft.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footer.copyWith(color: t.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                footerRight.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.footer.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
