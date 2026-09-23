import 'package:flutter/material.dart';

class DesignTokens {
  final Color paper;
  final Color edge;
  final Color raised;
  final Color ink;
  final Color inkDim;
  final Color muted;
  final Color faint;
  final Color line;
  final Color lineSoft;
  final Color lineStrong;
  final Color tint;
  final Color tint2;
  final BlendMode grainBlend;
  final double grainOpacity;

  const DesignTokens({
    required this.paper,
    required this.edge,
    required this.raised,
    required this.ink,
    required this.inkDim,
    required this.muted,
    required this.faint,
    required this.line,
    required this.lineSoft,
    required this.lineStrong,
    required this.tint,
    required this.tint2,
    required this.grainBlend,
    required this.grainOpacity,
  });

  static const dark = DesignTokens(
    paper: Color(0xFF0B0A09),
    edge: Color(0xFF050504),
    raised: Color(0xFF100E0D),
    ink: Color.fromRGBO(205, 196, 186, 1),
    inkDim: Color.fromRGBO(205, 196, 186, 0.86),
    muted: Color.fromRGBO(205, 196, 186, 0.60),
    faint: Color.fromRGBO(205, 196, 186, 0.40),
    line: Color.fromRGBO(205, 196, 186, 0.20),
    lineSoft: Color.fromRGBO(205, 196, 186, 0.10),
    lineStrong: Color.fromRGBO(205, 196, 186, 0.42),
    tint: Color.fromRGBO(205, 196, 186, 0.05),
    tint2: Color.fromRGBO(205, 196, 186, 0.10),
    grainBlend: BlendMode.overlay,
    grainOpacity: 0.04,
  );

  static const light = DesignTokens(
    paper: Color(0xFFECE7DD),
    edge: Color(0xFFE6E0D5),
    raised: Color(0xFFE3DDD1),
    ink: Color.fromRGBO(38, 34, 29, 1),
    inkDim: Color.fromRGBO(38, 34, 29, 0.82),
    muted: Color.fromRGBO(38, 34, 29, 0.58),
    faint: Color.fromRGBO(38, 34, 29, 0.38),
    line: Color.fromRGBO(38, 34, 29, 0.22),
    lineSoft: Color.fromRGBO(38, 34, 29, 0.11),
    lineStrong: Color.fromRGBO(38, 34, 29, 0.45),
    tint: Color.fromRGBO(38, 34, 29, 0.045),
    tint2: Color.fromRGBO(38, 34, 29, 0.09),
    grainBlend: BlendMode.multiply,
    grainOpacity: 0.05,
  );
}

class DesignTokensExtension extends ThemeExtension<DesignTokensExtension> {
  final DesignTokens tokens;
  const DesignTokensExtension(this.tokens);

  @override
  DesignTokensExtension copyWith() => this;

  @override
  DesignTokensExtension lerp(ThemeExtension<DesignTokensExtension>? other, double t) => this;
}

extension DesignTokensContext on BuildContext {
  DesignTokens get tokens => Theme.of(this).extension<DesignTokensExtension>()!.tokens;
}
