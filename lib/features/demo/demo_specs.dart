import '../../core/config/config_schema.dart';
import '../../core/providers/provider_spec.dart';
import '../uptime/domain/monitor_source.dart';
import '../vps/domain/hosts_source.dart';
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

HostsSource _createHost(SourceEntry entry, SourceDeps deps) =>
    DemoHostSource(clock: deps.clock);

MonitorSource _createUptime(SourceEntry entry, SourceDeps deps) =>
    DemoMonitorSource(clock: deps.clock);

String _label(SourceEntry entry) => 'Demo data';
