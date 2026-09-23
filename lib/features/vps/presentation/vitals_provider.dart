import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/http_client.dart';
import '../../../core/polling/polled.dart';
import '../data/webdock_source.dart';
import '../domain/host_vitals.dart';
import '../domain/vitals_source.dart';

final vitalsSourceProvider = Provider<VitalsSource>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(httpClientProvider);
  return WebdockSource(
    slug: config.webdock.slug,
    apiToken: config.webdock.apiToken,
    client: client,
  );
});

final vitalsProvider = polled<HostVitals>(
  (ref) => ref.watch(appConfigProvider).pollInterval,
  (ref) => ref.watch(vitalsSourceProvider).fetch(),
);
