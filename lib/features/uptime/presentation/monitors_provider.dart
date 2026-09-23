import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_provider.dart';
import '../../../core/net/http_client.dart';
import '../../../core/polling/polled.dart';
import '../data/uptime_kuma_metrics_source.dart';
import '../domain/monitor_source.dart';
import '../domain/monitor_status.dart';

final monitorSourceProvider = Provider<MonitorSource>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ref.watch(httpClientProvider);
  return UptimeKumaMetricsSource(
    url: config.kuma.url,
    apiKey: config.kuma.apiKey,
    client: client,
  );
});

final monitorsProvider = polled<List<MonitorStatus>>(
  (ref) => ref.watch(appConfigProvider).pollInterval,
  (ref) => ref.watch(monitorSourceProvider).fetch(),
);
