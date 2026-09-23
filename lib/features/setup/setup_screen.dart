import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/panel_title.dart';
import '../../shared/widgets/window_frame.dart';
import '../../version.dart';
import '../dashboard/dashboard_header.dart';
import '../settings/settings_screen.dart';

class SetupScreen extends StatelessWidget {
  final String configPath;
  final ConfigError? error;
  final VoidCallback onOpenFolder;

  const SetupScreen({
    super.key,
    required this.configPath,
    required this.error,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kurokan',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: Builder(
        builder: (context) {
          final t = context.tokens;
          return Material(
            color: t.paper,
            child: WindowFrame(
              marginMetaText: 'V$appVersion',
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
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _SetupPanel(
                          onOpenFolder: onOpenFolder,
                          configPath: configPath,
                          error: error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final VoidCallback onOpenFolder;
  final String configPath;
  final ConfigError? error;

  const _SetupPanel({
    required this.onOpenFolder,
    required this.configPath,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final osLabel = Platform.isMacOS ? 'MACOS' : 'LINUX';
    final isInvalid = error != null && !error!.notFound;
    final tag = isInvalid ? 'INVALID CONFIG' : 'GET STARTED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelTitle(title: 'Setup', tag: tag),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(minHeight: 30),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.lineSoft, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  osLabel,
                  style: AppTypography.kvLabel.copyWith(color: t.muted),
                ),
              ),
              Expanded(
                child: Text(
                  configPath,
                  style: AppTypography.row.copyWith(color: t.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isInvalid
              ? error!.reason.toUpperCase()
              : 'No config found yet. Enter your Webdock and Uptime Kuma details and the dashboard loads on its own.',
          style: isInvalid
              ? AppTypography.errMsg.copyWith(color: t.ink)
              : AppTypography.setupStep.copyWith(color: t.ink),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DossierButton(
              label: 'Set up now',
              visual: DossierButtonVisual.active,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(initial: null, configPath: configPath),
                ),
              ),
            ),
            DossierButton(label: 'Open config folder', onPressed: onOpenFolder),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.line, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isInvalid
                    ? 'INVALID CONFIG · WATCHING FOR FILE'
                    : 'NO CONFIG · WATCHING FOR FILE',
                style: AppTypography.footer.copyWith(color: t.ink),
              ),
              Text(
                'RELOADS ON SAVE',
                style: AppTypography.footer.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
