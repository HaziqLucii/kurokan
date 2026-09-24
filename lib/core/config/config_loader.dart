import 'dart:convert';

import '../platform/config_store.dart';
import 'app_config.dart';

class ConfigLoader {
  final Map<String, String> env;
  final String home;
  late final ConfigStore _store = createConfigStore(env: env, home: home);

  ConfigLoader({required this.env, required this.home});

  String get filePath => _store.path;

  String get dir => _store.dir;

  void ensureDir() => _store.ensureDir();

  AppConfig load() {
    if (!_store.exists()) {
      throw ConfigError(filePath, 'not found', notFound: true);
    }

    final String raw;
    try {
      raw = _store.read();
    } catch (e) {
      // Not covered by a test: reaching this needs a file that exists()
      // returns true for but read() still fails on (e.g. chmod 000), which
      // is permission-flaky across dev machines and CI runners.
      throw ConfigError(filePath, 'unreadable: $e');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw ConfigError(filePath, 'invalid JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw ConfigError(filePath, 'root must be a JSON object');
    }

    try {
      return AppConfig.fromJson(decoded);
    } on FormatException catch (e) {
      throw ConfigError(filePath, e.message);
    }
  }
}
