import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_provider.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/window_frame.dart';
import '../containers/presentation/containers_provider.dart';
import '../settings/settings_screen.dart';
import '../uptime/presentation/uptime_provider.dart';
import '../vps/presentation/hosts_provider.dart';
import 'dashboard_header.dart';
import 'dashboard_layout.dart';
import 'last_refresh_provider.dart';
import 'panel_grid.dart';
import 'panel_registry.dart';

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
    ref.invalidate(uptimeProvider);
    ref.invalidate(hostsProvider);
    ref.invalidate(containersProvider);
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
    final marginMeta = ref.watch(marginMetaProvider);
    final panels = ref.watch(panelRegistryProvider);

    final initialLoading = panels.any(
      (p) => p.isLoading && p.fetchedAt == null,
    );
    final refreshing = panels.any((p) => p.isLoading);

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
                  child: PanelGrid(plan: planLayout(panels, containerWidth)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
