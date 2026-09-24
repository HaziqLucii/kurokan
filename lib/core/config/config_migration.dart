bool isV1Config(Map<String, dynamic> raw) =>
    raw['version'] == null &&
    raw.containsKey('webdock') &&
    raw.containsKey('kuma');

/// Migrates a v1 (`webdock`/`kuma` sections) config to the v2
/// (`hosts`/`uptime`/`containers` lists) shape, in memory only. Never
/// written back to disk on its own: the config watcher would otherwise
/// loop on its own rewrite. The next Settings save persists v2 for real.
Map<String, dynamic> migrateV1ToV2(Map<String, dynamic> raw) {
  final webdock = raw['webdock'];
  final kuma = raw['kuma'];

  return {
    'version': 2,
    if (raw['pollIntervalSec'] != null)
      'pollIntervalSec': raw['pollIntervalSec'],
    if (raw['theme'] != null) 'theme': raw['theme'],
    'hosts': [
      if (webdock is Map<String, dynamic>)
        {'id': 'webdock', 'provider': 'webdock', ...webdock},
    ],
    'uptime': [
      if (kuma is Map<String, dynamic>)
        {'id': 'kuma', 'provider': 'kuma', ...kuma},
    ],
    'containers': <Map<String, dynamic>>[],
  };
}
