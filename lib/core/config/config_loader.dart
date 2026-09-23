import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

class ConfigLoader {
  final Map<String, String> env;
  final String home;

  const ConfigLoader({required this.env, required this.home});

  String get filePath {
    final override = env['KUROKAN_CONFIG'];
    if (override != null && override.isNotEmpty) return override;
    return '$home/.config/kurokan/config.json';
  }

  String get dir {
    final slash = filePath.lastIndexOf('/');
    return slash == -1 ? '.' : filePath.substring(0, slash);
  }

  AppConfig load() {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ConfigError(filePath, 'not found', notFound: true);
    }

    final String raw;
    try {
      raw = file.readAsStringSync();
    } on IOException catch (e) {
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
