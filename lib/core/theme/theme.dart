import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? DesignTokens.dark
      : DesignTokens.light;
  return ThemeData(
    brightness: brightness,
    fontFamily: 'Space Mono',
    scaffoldBackgroundColor: tokens.paper,
    canvasColor: tokens.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: tokens.tint,
    extensions: [DesignTokensExtension(tokens)],
  );
}
