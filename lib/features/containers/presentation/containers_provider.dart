import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/http_client.dart';
import '../../../core/polling/polled.dart';
import '../../../core/providers/provider_spec.dart';
import '../../../core/providers/registry_provider.dart';
import '../domain/container_status.dart';

final containersSourceProvider = Provider.family<ContainerSource, String>((
  ref,
  sourceId,
) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(httpClientProvider);
  final registry = ref.watch(providerRegistryProvider);
  final entry = config.containers.firstWhere((c) => c.id == sourceId);
  // Safe: entry.provider was already validated against this same registry
  // when the config was parsed (AppConfig.fromJson rejects unknown
  // providers), so the spec is guaranteed to exist here.
  final spec = registry.containerSpec(entry.provider)!;
  return spec.create(entry, SourceDeps(client: client, clock: clock));
});

final containersProvider = polledFamily<List<ContainerStatus>, String>(
  (ref, sourceId) => ref.watch(appConfigProvider).pollInterval,
  (ref, sourceId) => ref.watch(containersSourceProvider(sourceId)).fetch(),
);
