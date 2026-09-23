import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const marginMeta = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 10,
    letterSpacing: 10 * 0.34,
  );

  static const wordmarkBase = TextStyle(
    fontFamily: 'Fraunces',
    fontVariations: [FontVariation('wght', 300), FontVariation('opsz', 144)],
    height: 0.82,
  );

  static const lastLabel = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.92,
    letterSpacing: 9.92 * 0.22,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const button = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.2,
  );

  static const panelTitle = TextStyle(
    fontFamily: 'Space Grotesk',
    fontWeight: FontWeight.w500,
    fontSize: 12.48,
    letterSpacing: 12.48 * 0.16,
  );

  static const panelTag = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.16,
  );

  static const colHeader = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.28,
    letterSpacing: 9.28 * 0.2,
  );

  static const row = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 11.52,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const rowType = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.12,
  );

  static const rowCert = TextStyle(fontFamily: 'Space Mono', fontSize: 9.92);

  static const glyph = TextStyle(fontFamily: 'Space Mono', fontSize: 10.56);

  static const glyphDown = TextStyle(fontFamily: 'Space Mono', fontSize: 9.92);

  static const downLabel = TextStyle(
    fontFamily: 'Space Mono',
    fontWeight: FontWeight.w700,
    fontSize: 10.24,
    letterSpacing: 10.24 * 0.16,
  );

  static const kvLabel = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.16,
  );

  static const kvValue = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 11.52,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const tileNum = TextStyle(
    fontFamily: 'Space Grotesk',
    fontSize: 41.6,
    height: 1,
    letterSpacing: 41.6 * -0.02,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const tileUnit = TextStyle(
    fontFamily: 'Space Grotesk',
    fontSize: 14.4,
  );

  static const tileLabel = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.22,
  );

  static const tileSub = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const footer = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const errChip = TextStyle(
    fontFamily: 'Space Mono',
    fontWeight: FontWeight.w700,
    fontSize: 9.28,
    letterSpacing: 9.28 * 0.2,
  );

  static const errMsg = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 10.88,
    letterSpacing: 10.88 * 0.12,
  );

  static const errHint = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 9.6,
    letterSpacing: 9.6 * 0.2,
  );

  static const pre = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 10.88,
    height: 1.65,
  );

  static const setupStep = TextStyle(
    fontFamily: 'Space Mono',
    fontSize: 10.88,
    height: 1.5,
  );

  static const watermark = TextStyle(
    fontFamily: 'Noto Serif JP',
    fontWeight: FontWeight.w300,
    height: 1,
  );
}
