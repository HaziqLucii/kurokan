import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'panel_registry.dart';

final lastRefreshProvider = Provider<DateTime?>((ref) {
  final panels = ref.watch(panelRegistryProvider);
  DateTime? latest;
  for (final panel in panels) {
    final at = panel.fetchedAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
});
