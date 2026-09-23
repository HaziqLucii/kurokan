import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_provider.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/window_frame.dart';
import '../../version.dart';
import '../uptime/presentation/monitor_skeleton.dart';
import '../vps/presentation/vitals_skeleton.dart';
import 'dashboard_header.dart';
import 'panel_frame.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final t = context.tokens;
    final marginMeta = '${config.webdock.slug} · POLL ${config.pollInterval.inSeconds}S · V$appVersion';

    return Material(
      color: t.paper,
      child: WindowFrame(
        marginMetaText: marginMeta,
        contentBuilder: (context, containerWidth) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardHeader(
              containerWidth: containerWidth,
              lastText: '--:--:--',
              refreshLabel: '↻ Refresh',
              refreshVisual: DossierButtonVisual.disabled,
              onRefresh: null,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 62,
                    child: PanelFrame(
                      title: 'Monitors',
                      tag: '—',
                      body: const MonitorSkeleton(),
                      footerLeft: 'Loading',
                      footerRight: '—',
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 38,
                    child: PanelFrame(
                      title: 'Vitals',
                      tag: 'Webdock',
                      body: const VitalsSkeleton(),
                      footerLeft: 'Loading',
                      footerRight: '—',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
