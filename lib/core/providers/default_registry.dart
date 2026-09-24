import '../../features/uptime/data/kuma_spec.dart';
import '../../features/vps/data/webdock_spec.dart';
import 'provider_registry.dart';

const defaultRegistry = ProviderRegistry(
  hosts: [webdockSpec],
  uptime: [kumaSpec],
  containers: [],
);
