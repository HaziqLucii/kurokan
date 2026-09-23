import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/halftone_dot.dart';
import '../../shared/widgets/panel_title.dart';
import '../../shared/widgets/window_frame.dart';
import '../../version.dart';
import '../dashboard/dashboard_header.dart';

const _expectedShapeJson = '''
{
  "webdock": {
    "slug": "webdock-prod-01",
    "apiToken": "••••••••••••"
  },
  "kuma": {
    "url": "https://status.example.tld",
    "apiKey": "••••••••"
  },
  "pollIntervalSec": 30,
  "theme": "system"
}''';

const _setupSteps = [
  'Create config.json at the path above.',
  'Add the Webdock server slug and apiToken.',
  'Add the Uptime Kuma url and apiKey.',
  'Save. The dashboard loads on its own.',
];

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
      title: 'infra-monitor',
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 62, child: _ConfigPanel(configPath: configPath, error: error)),
                        const SizedBox(width: 40),
                        Expanded(flex: 38, child: _SetupPanel(onOpenFolder: onOpenFolder)),
                      ],
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

class _ConfigPanel extends StatelessWidget {
  final String configPath;
  final ConfigError? error;

  const _ConfigPanel({required this.configPath, required this.error});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final osLabel = Platform.isMacOS ? 'MACOS' : 'LINUX';
    final isInvalid = error != null && !error!.notFound;
    final tag = isInvalid ? 'INVALID' : 'NOT FOUND';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelTitle(title: 'Config', tag: tag),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 30),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.lineSoft, width: 1))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(osLabel, style: AppTypography.kvLabel.copyWith(color: t.muted)),
                      ),
                      Expanded(child: Text(configPath, style: AppTypography.row.copyWith(color: t.ink))),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('EXPECTED SHAPE', style: AppTypography.colHeader.copyWith(color: t.faint)),
                if (isInvalid) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!.reason.toUpperCase(),
                    style: AppTypography.errMsg.copyWith(color: t.ink),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: t.line, width: 1), color: t.raised),
                  child: Text(_expectedShapeJson, style: AppTypography.pre.copyWith(color: t.ink)),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: 1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isInvalid ? 'INVALID CONFIG · WATCHING FOR FILE' : 'NO CONFIG · WATCHING FOR FILE',
                style: AppTypography.footer.copyWith(color: t.ink),
              ),
              Text('RELOADS ON SAVE', style: AppTypography.footer.copyWith(color: t.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final VoidCallback onOpenFolder;

  const _SetupPanel({required this.onOpenFolder});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelTitle(title: 'Setup', tag: '04 STEPS'),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _setupSteps.length; i++)
                    _StepRow(index: i + 1, text: _setupSteps[i], lineSoft: t.lineSoft, faint: t.faint, ink: t.ink),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DossierButton(label: 'Open config folder', onPressed: onOpenFolder),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line, width: 1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FIRST LAUNCH', style: AppTypography.footer.copyWith(color: t.ink)),
                  Text('V$appVersion', style: AppTypography.footer.copyWith(color: t.muted)),
                ],
              ),
            ),
          ],
        ),
        const Positioned(right: 0, bottom: 6, child: HalftoneDot()),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;
  final Color lineSoft;
  final Color faint;
  final Color ink;

  const _StepRow({
    required this.index,
    required this.text,
    required this.lineSoft,
    required this.faint,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lineSoft, width: 1))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(index.toString().padLeft(2, '0'), style: AppTypography.setupStep.copyWith(color: faint)),
          ),
          Expanded(child: Text(text, style: AppTypography.setupStep.copyWith(color: ink))),
        ],
      ),
    );
  }
}
