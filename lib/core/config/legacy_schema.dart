import 'config_schema.dart';

/// Minimal [ConfigSchema] covering only the two providers Kurokan supports
/// today (webdock, kuma). Temporary: Phase 1.2's ProviderRegistry
/// implements ConfigSchema for real, with a provider spec per source, and
/// replaces this file entirely.
const legacyConfigSchema = _LegacySchema();

class _LegacySchema implements ConfigSchema {
  const _LegacySchema();

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
