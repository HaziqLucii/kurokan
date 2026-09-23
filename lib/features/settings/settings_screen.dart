import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_writer.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/panel_title.dart';
import '../../shared/widgets/window_frame.dart';
import 'settings_form.dart';

class SettingsScreen extends StatelessWidget {
  final AppConfig? initial;
  final String configPath;

  const SettingsScreen({
    super.key,
    required this.initial,
    required this.configPath,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isEdit = initial != null;
    return Material(
      color: t.paper,
      child: WindowFrame(
        marginMetaText: 'SETTINGS',
        contentBuilder: (context, containerWidth) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: PanelTitle(
                    title: 'Settings',
                    tag: isEdit ? 'Edit config' : 'First setup',
                  ),
                ),
                const SizedBox(width: 12),
                DossierButton(
                  label: '← Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SettingsForm(
                    initial: initial,
                    onSave: (config) {
                      try {
                        ConfigWriter(configPath).write(config);
                      } catch (e) {
                        return 'Failed to save: $e';
                      }
                      Navigator.of(context).maybePop();
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
