import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_provider.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/window_frame.dart';
import '../settings/settings_screen.dart';
import '../uptime/presentation/uptime_provider.dart';
import '../vps/presentation/hosts_provider.dart';
import 'dashboard_header.dart';
import 'last_refresh_provider.dart';
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

    final widePanels = panels.where((p) => p.slot == PanelSlot.wide).toList();
    final narrowPanels = panels
        .where((p) => p.slot == PanelSlot.narrow)
        .toList();

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
                      Expanded(
                        flex: 62,
                        child: _PanelColumn(panels: widePanels),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 38,
                        child: _PanelColumn(panels: narrowPanels),
                      ),
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

/// Phase 1.4 scope: stacks multiple panels in the same slot vertically.
/// The actual responsive multi-panel layout (breakpoints, single column)
/// is Phase 1.5's job; this just has to not break when a config has more
/// than one source of a kind.
class _PanelColumn extends StatelessWidget {
  final List<PanelEntry> panels;
  const _PanelColumn({required this.panels});

  @override
  Widget build(BuildContext context) {
    if (panels.isEmpty) return const SizedBox.shrink();
    if (panels.length == 1) return panels.first.build();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final panel in panels) ...[
          Expanded(child: panel.build()),
          if (panel.key != panels.last.key) const SizedBox(height: 24),
        ],
      ],
    );
  }
}
