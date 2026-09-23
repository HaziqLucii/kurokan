import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/config_provider.dart';
import 'core/theme/theme.dart';
import 'features/dashboard/dashboard_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp(
      title: 'Kurokan',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode(config.theme),
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const DashboardScreen(),
    );
  }

  ThemeMode _themeMode(ThemePreference pref) => switch (pref) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.light => ThemeMode.light,
      };
}
