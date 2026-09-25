import '../../core/config/config_schema.dart';
import '../../core/providers/provider_spec.dart';
import '../containers/domain/container_status.dart';
import '../uptime/domain/monitor_source.dart';
import '../vps/domain/hosts_source.dart';
import 'demo_container_source.dart';
import 'demo_host_source.dart';
import 'demo_monitor_source.dart';

const demoHostSpec = ProviderSpec<HostsSource>(
  id: 'demo',
  tag: 'DEMO',
  kind: SourceKind.host,
  fields: [],
  create: _createHost,
  label: _label,
);

const demoUptimeSpec = ProviderSpec<MonitorSource>(
  id: 'demo',
  tag: 'DEMO',
  kind: SourceKind.uptime,
  fields: [],
  create: _createUptime,
  label: _label,
);

const demoContainerSpec = ProviderSpec<ContainerSource>(
  id: 'demo',
  tag: 'DEMO',
  kind: SourceKind.containers,
  fields: [],
  create: _createContainer,
  label: _label,
);

HostsSource _createHost(SourceEntry entry, SourceDeps deps) =>
    DemoHostSource(clock: deps.clock);

MonitorSource _createUptime(SourceEntry entry, SourceDeps deps) =>
    DemoMonitorSource(clock: deps.clock);

ContainerSource _createContainer(SourceEntry entry, SourceDeps deps) =>
    DemoContainerSource(clock: deps.clock);

String _label(SourceEntry entry) => 'Demo data';
