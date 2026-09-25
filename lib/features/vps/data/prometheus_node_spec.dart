import '../../../core/config/config_schema.dart';
import '../../../core/providers/provider_spec.dart';
import '../domain/hosts_source.dart';
import 'prometheus_node_source.dart';

const prometheusNodeSpec = ProviderSpec<HostsSource>(
  id: 'prometheus',
  tag: 'PROM',
  kind: SourceKind.host,
  fields: [
    FieldSpec(
      key: 'url',
      label: 'URL',
      kind: FieldKind.url,
      hint: 'Base URL, e.g. http://host:9090',
    ),
    FieldSpec(
      key: 'authToken',
      label: 'Auth token',
      kind: FieldKind.secret,
      required: false,
      hint: 'Bearer token, only if your endpoint requires one',
    ),
    FieldSpec(
      key: 'job',
      label: 'Job',
      kind: FieldKind.text,
      required: false,
      hint: 'Restrict to one scrape job (optional)',
    ),
    FieldSpec(
      key: 'instanceRegex',
      label: 'Instance filter',
      kind: FieldKind.text,
      required: false,
      hint: 'Regex over the instance label (optional)',
    ),
    FieldSpec(
      key: 'networkQuotaGiB',
      label: 'Network quota (GiB per 24h)',
      kind: FieldKind.integer,
      required: false,
      hint:
          'Compared against a rolling 24h receive+transmit total, not a monthly figure',
    ),
  ],
  create: _create,
  label: _label,
);

HostsSource _create(SourceEntry entry, SourceDeps deps) => PrometheusNodeSource(
  url: entry.settings['url']!,
  auth: entry.settings['authToken'] == null
      ? null
      : PromAuth(bearerToken: entry.settings['authToken']),
  job: entry.settings['job'],
  instanceRegex: entry.settings['instanceRegex'],
  networkQuotaGiB: entry.settings['networkQuotaGiB'] == null
      ? null
      : double.tryParse(entry.settings['networkQuotaGiB']!),
  client: deps.client,
);

String _label(SourceEntry entry) => entry.settings['url'] ?? entry.id;
