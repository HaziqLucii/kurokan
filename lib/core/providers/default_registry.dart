import '../../features/containers/data/docker_spec.dart';
import '../../features/demo/demo_specs.dart';
import '../../features/uptime/data/kuma_spec.dart';
import '../../features/vps/data/prometheus_node_spec.dart';
import '../../features/vps/data/webdock_spec.dart';
import 'provider_registry.dart';

const defaultRegistry = ProviderRegistry(
  hosts: [webdockSpec, prometheusNodeSpec, demoHostSpec],
  uptime: [kumaSpec, demoUptimeSpec],
  containers: [dockerSpec, demoContainerSpec],
);
