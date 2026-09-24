import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_provider.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/window_frame.dart';
import '../../version.dart';
import '../settings/settings_screen.dart';
import '../uptime/presentation/monitor_panel.dart';
import '../uptime/presentation/monitors_provider.dart';
import '../vps/presentation/vitals_panel.dart';
import '../vps/presentation/vitals_provider.dart';
import 'dashboard_header.dart';
import 'last_refresh_provider.dart';

const _manualRefreshDebounce = Duration(seconds: 5);

String _formatTime(DateTime? t) {
  if (t == null) return '--:--:--';
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _lastManualRefresh;

  void _handleRefresh() {
    final now = clock.now();
    if (_lastManualRefresh != null &&
        now.difference(_lastManualRefresh!) < _manualRefreshDebounce) {
      return;
    }
    _lastManualRefresh = now;
    ref.invalidate(monitorsProvider);
    ref.invalidate(vitalsProvider);
  }

  void _openSettings(AppConfig config, String configPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(initial: config, configPath: configPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final t = context.tokens;
    final marginMeta =
        '${config.firstHost?.settings['slug'] ?? '?'} · POLL ${config.pollInterval.inSeconds}S · V$appVersion';

    final monitorsAsync = ref.watch(monitorsProvider);
    final vitalsAsync = ref.watch(vitalsProvider);
    final initialLoading =
        (monitorsAsync.isLoading && !monitorsAsync.hasValue) ||
        (vitalsAsync.isLoading && !vitalsAsync.hasValue);
    final refreshing = monitorsAsync.isLoading || vitalsAsync.isLoading;

    final refreshVisual = initialLoading
        ? DossierButtonVisual.disabled
        : refreshing
        ? DossierButtonVisual.active
        : DossierButtonVisual.idle;
    final refreshLabel = refreshing && !initialLoading
        ? 'Refreshing'
        : '↻ Refresh';

    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR):
            _handleRefresh,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
            _handleRefresh,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: t.paper,
          child: WindowFrame(
            marginMetaText: marginMeta,
            contentBuilder: (context, containerWidth) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardHeader(
                  containerWidth: containerWidth,
                  lastText: _formatTime(ref.watch(lastRefreshProvider)),
                  refreshLabel: refreshLabel,
                  refreshVisual: refreshVisual,
                  onRefresh: initialLoading ? null : _handleRefresh,
                  onSettings: () =>
                      _openSettings(config, ref.read(configPathProvider)),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 62, child: MonitorPanel()),
                      const SizedBox(width: 40),
                      const Expanded(flex: 38, child: VitalsPanel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
