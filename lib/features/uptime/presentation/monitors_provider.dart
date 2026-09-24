import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/http_client.dart';
import '../../../core/polling/polled.dart';
import '../../../core/providers/provider_spec.dart';
import '../../../core/providers/registry_provider.dart';
import '../domain/monitor_source.dart';
import '../domain/monitor_status.dart';

final monitorSourceProvider = Provider<MonitorSource>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(httpClientProvider);
  final registry = ref.watch(providerRegistryProvider);
  // firstUptime is a Phase 1.1 compatibility shim (single-source config);
  // Phase 1.4 replaces this with real N-source polling.
  final uptime = config.firstUptime!;
  // Safe: uptime.provider was already validated against this same registry
  // when the config was parsed (AppConfig.fromJson rejects unknown
  // providers), so the spec is guaranteed to exist here.
  final spec = registry.uptimeSpec(uptime.provider)!;
  return spec.create(uptime, SourceDeps(client: client, clock: clock));
});

final monitorsProvider = polled<List<MonitorStatus>>(
  (ref) => ref.watch(appConfigProvider).pollInterval,
  (ref) => ref.watch(monitorSourceProvider).fetch(),
);
