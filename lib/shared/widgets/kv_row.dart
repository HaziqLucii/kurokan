import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

class KvRow extends StatelessWidget {
  final String label;
  final Widget value;

  const KvRow({super.key, required this.label, required this.value});

  factory KvRow.text(String label, String value, {Key? key}) {
    return KvRow(key: key, label: label, value: _KvValueText(value));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.lineSoft, width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: AppTypography.kvLabel.copyWith(color: t.muted)),
          value,
        ],
      ),
    );
  }
}

class _KvValueText extends StatelessWidget {
  final String text;
  const _KvValueText(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(text, style: AppTypography.kvValue.copyWith(color: t.ink));
  }
}
