import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_schema.dart';

/// [ConfigSchema] for tests: knows exactly the two providers the app
/// supports pre-Phase-1.2 (webdock, kuma). Mirrors
/// `lib/core/config/legacy_schema.dart`, kept separate since `lib/` and
/// `test/` don't share importable code.
const testConfigSchema = _TestConfigSchema();

class _TestConfigSchema implements ConfigSchema {
  const _TestConfigSchema();

  static const _webdockFields = [
    FieldSpec(key: 'slug', label: 'Slug', kind: FieldKind.text),
    FieldSpec(key: 'apiToken', label: 'API token', kind: FieldKind.secret),
  ];

  static const _kumaFields = [
    FieldSpec(key: 'url', label: 'URL', kind: FieldKind.url),
    FieldSpec(key: 'apiKey', label: 'API key', kind: FieldKind.secret),
  ];

  @override
  List<FieldSpec>? hostFields(String provider) =>
      provider == 'webdock' ? _webdockFields : null;

  @override
  List<FieldSpec>? uptimeFields(String provider) =>
      provider == 'kuma' ? _kumaFields : null;

  @override
  List<FieldSpec>? containerFields(String provider) => null;

  @override
  List<String> providerIds(SourceKind kind) => switch (kind) {
    SourceKind.host => const ['webdock'],
    SourceKind.uptime => const ['kuma'],
    SourceKind.containers => const [],
  };
}

/// Builds an [AppConfig] with one webdock host and one kuma uptime source,
/// the shape every test used before Phase 1.1's N-source model landed.
AppConfig testConfig({
  String webdockSlug = 'demo',
  String webdockToken = 'wd_secret',
  String kumaUrl = 'https://kuma.test',
  String kumaApiKey = 'uk1_secret',
  Duration pollInterval = const Duration(seconds: 30),
  ThemePreference theme = ThemePreference.system,
}) => AppConfig(
  hosts: [
    SourceEntry(
      kind: SourceKind.host,
      id: 'webdock',
      provider: 'webdock',
      settings: {'slug': webdockSlug, 'apiToken': webdockToken},
    ),
  ],
  uptime: [
    SourceEntry(
      kind: SourceKind.uptime,
      id: 'kuma',
      provider: 'kuma',
      settings: {'url': kumaUrl, 'apiKey': kumaApiKey},
    ),
  ],
  pollInterval: pollInterval,
  theme: theme,
);

/// Builds the raw JSON map `testConfig()` would parse from, for tests that
/// exercise `AppConfig.fromJson` directly.
Map<String, dynamic> testConfigJson({
  String webdockSlug = 'demo',
  String webdockToken = 'wd_secret',
  String kumaUrl = 'https://kuma.test',
  String kumaApiKey = 'uk1_secret',
  int? pollIntervalSec,
  String? theme,
}) => {
  'version': 2,
  'pollIntervalSec': ?pollIntervalSec,
  'theme': ?theme,
  'hosts': [
    {
      'id': 'webdock',
      'provider': 'webdock',
      'slug': webdockSlug,
      'apiToken': webdockToken,
    },
  ],
  'uptime': [
    {'id': 'kuma', 'provider': 'kuma', 'url': kumaUrl, 'apiKey': kumaApiKey},
  ],
};
