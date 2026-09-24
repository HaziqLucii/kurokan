import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/http_client.dart';
import '../../../core/polling/polled.dart';
import '../../../core/providers/provider_spec.dart';
import '../../../core/providers/registry_provider.dart';
import '../domain/host_vitals.dart';
import '../domain/vitals_source.dart';

final vitalsSourceProvider = Provider<VitalsSource>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(httpClientProvider);
  final registry = ref.watch(providerRegistryProvider);
  // firstHost is a Phase 1.1 compatibility shim (single-source config);
  // Phase 1.4 replaces this with real N-source polling.
  final host = config.firstHost!;
  // Safe: host.provider was already validated against this same registry
  // when the config was parsed (AppConfig.fromJson rejects unknown
  // providers), so the spec is guaranteed to exist here.
  final spec = registry.hostSpec(host.provider)!;
  return spec.create(host, SourceDeps(client: client, clock: clock));
});

final vitalsProvider = polled<HostVitals>(
  (ref) => ref.watch(appConfigProvider).pollInterval,
  (ref) => ref.watch(vitalsSourceProvider).fetch(),
);
