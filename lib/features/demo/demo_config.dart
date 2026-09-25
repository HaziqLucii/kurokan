import '../../core/config/app_config.dart';
import '../../core/config/config_schema.dart';

/// A config that renders entirely with synthetic data, no real credentials.
/// Written to disk by the setup screen's "Try with demo data" button; loads
/// through the exact same registry-driven path as any real config, since
/// the "demo" provider is just another entry in [defaultRegistry].
AppConfig demoConfig() => const AppConfig(
  hosts: [
    SourceEntry(
      kind: SourceKind.host,
      id: 'demo-host',
      provider: 'demo',
      settings: {},
    ),
  ],
  uptime: [
    SourceEntry(
      kind: SourceKind.uptime,
      id: 'demo-uptime',
      provider: 'demo',
      settings: {},
    ),
  ],
  containers: [
    SourceEntry(
      kind: SourceKind.containers,
      id: 'demo-containers',
      provider: 'demo',
      settings: {},
    ),
  ],
);
