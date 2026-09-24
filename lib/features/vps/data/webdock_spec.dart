import '../../../core/config/config_schema.dart';
import '../../../core/providers/provider_spec.dart';
import '../domain/hosts_source.dart';
import 'webdock_source.dart';

const webdockSpec = ProviderSpec<HostsSource>(
  id: 'webdock',
  tag: 'WEBDOCK',
  kind: SourceKind.host,
  fields: [
    FieldSpec(key: 'slug', label: 'Slug', kind: FieldKind.text),
    FieldSpec(key: 'apiToken', label: 'API token', kind: FieldKind.secret),
  ],
  create: _create,
  label: _label,
);

HostsSource _create(SourceEntry entry, SourceDeps deps) => WebdockSource(
  slug: entry.settings['slug']!,
  apiToken: entry.settings['apiToken']!,
  client: deps.client,
);

String _label(SourceEntry entry) => entry.settings['slug'] ?? entry.id;
