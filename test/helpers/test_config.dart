import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/core/providers/default_registry.dart';

/// The real registry every provider ships with (webdock, kuma). Used
/// directly as the [ConfigSchema] in tests instead of a hand-duplicated
/// fixture, so tests validate against what the app actually recognizes.
const testConfigSchema = defaultRegistry;

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
