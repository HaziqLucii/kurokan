import '../../features/containers/domain/container_status.dart';
import '../../features/uptime/domain/monitor_source.dart';
import '../../features/vps/domain/hosts_source.dart';
import '../config/config_schema.dart';
import 'provider_spec.dart';

class ProviderRegistry implements ConfigSchema {
  final List<ProviderSpec<HostsSource>> hosts;
  final List<ProviderSpec<MonitorSource>> uptime;
  final List<ProviderSpec<ContainerSource>> containers;

  const ProviderRegistry({
    this.hosts = const [],
    this.uptime = const [],
    this.containers = const [],
  });

  ProviderSpec<HostsSource>? hostSpec(String id) => _byId(hosts, id);

  ProviderSpec<MonitorSource>? uptimeSpec(String id) => _byId(uptime, id);

  ProviderSpec<ContainerSource>? containerSpec(String id) =>
      _byId(containers, id);

  static ProviderSpec<S>? _byId<S>(List<ProviderSpec<S>> specs, String id) {
    for (final spec in specs) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  @override
  List<FieldSpec>? hostFields(String provider) => hostSpec(provider)?.fields;

  @override
  List<FieldSpec>? uptimeFields(String provider) =>
      uptimeSpec(provider)?.fields;

  @override
  List<FieldSpec>? containerFields(String provider) =>
      containerSpec(provider)?.fields;

  @override
  List<String> providerIds(SourceKind kind) => switch (kind) {
    SourceKind.host => [for (final s in hosts) s.id],
    SourceKind.uptime => [for (final s in uptime) s.id],
    SourceKind.containers => [for (final s in containers) s.id],
  };
}
