import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/config_loader.dart';
import 'core/config/config_provider.dart';
import 'core/config/config_watcher.dart';
import 'core/platform/environment.dart';
import 'core/platform/open_folder.dart';
import 'core/platform/platform_info.dart';
import 'core/providers/default_registry.dart';
import 'features/demo/demo_config.dart';
import 'features/setup/setup_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final ConfigLoader _loader;
  AppConfig? _config;
  ConfigError? _error;
  int _gen = 0;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _loader = ConfigLoader(
      env: environment,
      home: environment['HOME'] ?? '',
      schema: defaultRegistry,
    );
    if (PlatformInfo.isDemo) {
      // Zero-setup launch (--dart-define=KUROKAN_DEMO=true): use an
      // in-memory demo config, never touch the real config file. Settings
      // can still write to the real path if opened, but nothing reads it
      // back in this mode, since neither ensureDir/load nor the watcher
      // run below.
      _config = demoConfig();
      return;
    }
    _loader.ensureDir();
    _tryLoad();
    _sub = ConfigWatcher(_loader.dir).events.listen((_) => _tryLoad());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _tryLoad() {
    setState(() {
      try {
        _config = _loader.load();
        _error = null;
        _gen++;
      } on ConfigError catch (e) {
        _config = null;
        _error = e;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return SetupScreen(
        configPath: _loader.filePath,
        error: _error,
        onOpenFolder: () => openFolder(_loader.dir),
      );
    }
    return ProviderScope(
      key: ValueKey(_gen),
      overrides: [
        appConfigProvider.overrideWithValue(config),
        configPathProvider.overrideWithValue(_loader.filePath),
      ],
      child: const App(),
    );
  }
}
