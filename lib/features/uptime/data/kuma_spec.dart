import '../../../core/config/config_schema.dart';
import '../../../core/providers/provider_spec.dart';
import '../domain/monitor_source.dart';
import 'uptime_kuma_metrics_source.dart';

const kumaSpec = ProviderSpec<MonitorSource>(
  id: 'kuma',
  tag: 'KUMA',
  kind: SourceKind.uptime,
  fields: [
    FieldSpec(key: 'url', label: 'URL', kind: FieldKind.url),
    FieldSpec(key: 'apiKey', label: 'API key', kind: FieldKind.secret),
  ],
  create: _create,
  label: _label,
);

MonitorSource _create(SourceEntry entry, SourceDeps deps) =>
    UptimeKumaMetricsSource(
      url: entry.settings['url']!,
      apiKey: entry.settings['apiKey']!,
      client: deps.client,
    );

String _label(SourceEntry entry) => entry.settings['url'] ?? entry.id;
