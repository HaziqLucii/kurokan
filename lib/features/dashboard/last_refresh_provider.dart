import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../uptime/presentation/monitors_provider.dart';
import '../vps/presentation/vitals_provider.dart';

final lastRefreshProvider = Provider<DateTime?>((ref) {
  final monitorsAt = ref.watch(monitorsProvider).value?.fetchedAt;
  final vitalsAt = ref.watch(vitalsProvider).value?.fetchedAt;

  if (monitorsAt == null) return vitalsAt;
  if (vitalsAt == null) return monitorsAt;
  return monitorsAt.isAfter(vitalsAt) ? monitorsAt : vitalsAt;
});
