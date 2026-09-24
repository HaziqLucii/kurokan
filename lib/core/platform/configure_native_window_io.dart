import 'dart:io' show Platform;

import 'package:macos_window_utils/macos_window_utils.dart';

Future<void> configureNativeWindow() async {
  if (!Platform.isMacOS) return;
  await WindowManipulator.initialize();
  await WindowManipulator.hideTitle();
  await WindowManipulator.makeTitlebarTransparent();
  await WindowManipulator.enableFullSizeContentView();
}
