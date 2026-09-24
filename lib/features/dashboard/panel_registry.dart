import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_provider.dart';
import '../../core/providers/registry_provider.dart';
import '../../version.dart';
import '../uptime/presentation/monitor_panel.dart';
import '../uptime/presentation/uptime_provider.dart';
import '../vps/presentation/hosts_provider.dart';
import '../vps/presentation/vitals_panel.dart';

enum PanelSlot { wide, narrow }

class PanelEntry {
  final String key;
  final String sourceId;
  final PanelSlot slot;
  final DateTime? fetchedAt;
  final bool isLoading;
  final bool hasError;
  final Widget Function() build;

  const PanelEntry({
    required this.key,
    required this.sourceId,
    required this.slot,
    required this.fetchedAt,
    required this.isLoading,
    required this.hasError,
    required this.build,
  });
}

/// Builds the dashboard's panel list from the actual configured sources,
/// one entry per source (not per provider): a config with two uptime
/// entries gets two Monitors panels. Ordered by `layout.order` when set,
/// config order otherwise (uptime sources first, then hosts).
final panelRegistryProvider = Provider<List<PanelEntry>>((ref) {
  final config = ref.watch(appConfigProvider);
  final entries = <PanelEntry>[];

  for (final uptime in config.uptime) {
    final async = ref.watch(uptimeProvider(uptime.id));
    entries.add(
      PanelEntry(
        key: 'uptime:${uptime.id}',
        sourceId: uptime.id,
        slot: PanelSlot.wide,
        fetchedAt: async.value?.fetchedAt,
        isLoading: async.isLoading,
        hasError: async.hasError,
        build: () => MonitorPanel(sourceId: uptime.id),
      ),
    );
  }
  for (final host in config.hosts) {
    final async = ref.watch(hostsProvider(host.id));
    entries.add(
      PanelEntry(
        key: 'host:${host.id}',
        sourceId: host.id,
        slot: PanelSlot.narrow,
        fetchedAt: async.value?.fetchedAt,
        isLoading: async.isLoading,
        hasError: async.hasError,
        build: () => VitalsPanel(sourceId: host.id),
      ),
    );
  }

  final order = config.layout.order;
  if (order.isNotEmpty) {
    entries.sort((a, b) {
      final aRank = order.indexOf(a.key);
      final bRank = order.indexOf(b.key);
      return (aRank == -1 ? order.length : aRank).compareTo(
        bRank == -1 ? order.length : bRank,
      );
    });
  }

  return entries;
});

/// The window-frame margin text: a single host's own label when there's
/// exactly one configured, otherwise a compact source-count summary.
final marginMetaProvider = Provider<String>((ref) {
  final config = ref.watch(appConfigProvider);
  final registry = ref.watch(providerRegistryProvider);
  final pollLabel = 'POLL ${config.pollInterval.inSeconds}S';

  final String sourceLabel;
  if (config.hosts.length == 1) {
    final host = config.hosts.first;
    sourceLabel = registry.hostSpec(host.provider)?.label(host) ?? host.id;
  } else {
    sourceLabel =
        '${config.hosts.length} HOSTS · ${config.uptime.length} UPTIME';
  }

  return '$sourceLabel · $pollLabel · V$appVersion';
});
