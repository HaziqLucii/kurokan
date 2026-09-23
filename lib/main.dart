import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import 'app_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) {
    await WindowManipulator.initialize();
    await WindowManipulator.hideTitle();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
  }
  runApp(const AppRoot());
}
