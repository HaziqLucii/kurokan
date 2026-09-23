import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_provider.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/window_frame.dart';
import '../../version.dart';
import '../uptime/presentation/monitor_panel.dart';
import '../vps/presentation/vitals_panel.dart';
import 'dashboard_header.dart';

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
                  const Expanded(flex: 62, child: MonitorPanel()),
                  const SizedBox(width: 40),
                  const Expanded(flex: 38, child: VitalsPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
