import 'package:flutter/material.dart';

import 'app_root.dart';
import 'core/platform/configure_native_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureNativeWindow();
  runApp(const AppRoot());
}
