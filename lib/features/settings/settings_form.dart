import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/dossier_button.dart';
import '../../shared/widgets/settings_field.dart';

class SettingsForm extends StatefulWidget {
  final AppConfig? initial;
  final String? Function(AppConfig config) onSave;

  const SettingsForm({super.key, required this.initial, required this.onSave});

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  late final TextEditingController _slugController;
  late final TextEditingController _tokenController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _pollController;
  late ThemePreference _theme;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _slugController = TextEditingController(text: initial?.webdock.slug ?? '');
    _tokenController = TextEditingController();
    _urlController = TextEditingController(text: initial?.kuma.url ?? '');
    _apiKeyController = TextEditingController();
    _pollController = TextEditingController(
      text:
          (initial?.pollInterval.inSeconds ??
                  AppConfig.defaultPollInterval.inSeconds)
              .toString(),
    );
    _theme = initial?.theme ?? ThemePreference.system;
  }

  @override
  void dispose() {
    _slugController.dispose();
    _tokenController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _pollController.dispose();
    super.dispose();
  }

  void _submit() {
    final slug = _slugController.text.trim();
    final url = _urlController.text.trim();
    final poll = int.tryParse(_pollController.text.trim());

    if (slug.isEmpty) {
      setState(() => _error = 'Webdock slug is required.');
      return;
    }
    if (url.isEmpty) {
      setState(() => _error = 'Kuma url is required.');
      return;
    }
    if (poll == null || poll <= 0) {
      setState(
        () => _error = 'Poll interval must be a positive number of seconds.',
      );
      return;
    }

    final typedToken = _tokenController.text.trim();
    final typedApiKey = _apiKeyController.text.trim();
    final token = typedToken.isEmpty
        ? widget.initial?.webdock.apiToken
        : typedToken;
    final apiKey = typedApiKey.isEmpty
        ? widget.initial?.kuma.apiKey
        : typedApiKey;

    if (token == null || token.isEmpty) {
      setState(() => _error = 'Webdock API token is required.');
      return;
    }
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error = 'Kuma API key is required.');
      return;
    }

    final saveError = widget.onSave(
      AppConfig(
        webdock: WebdockConfig(slug: slug, apiToken: token),
        kuma: KumaConfig(url: url, apiKey: apiKey),
        pollInterval: Duration(seconds: poll),
        theme: _theme,
      ),
    );
    setState(() => _error = saveError);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsField(label: 'Webdock slug', controller: _slugController),
        SettingsField(
          label: 'Webdock token',
          controller: _tokenController,
          obscureText: true,
          hintText: _isEdit ? 'Leave blank to keep existing' : null,
        ),
        SettingsField(label: 'Kuma url', controller: _urlController),
        SettingsField(
          label: 'Kuma api key',
          controller: _apiKeyController,
          obscureText: true,
          hintText: _isEdit ? 'Leave blank to keep existing' : null,
        ),
        SettingsField(
          label: 'Poll interval (s)',
          controller: _pollController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'THEME',
              style: AppTypography.kvLabel.copyWith(color: t.muted),
            ),
            const SizedBox(width: 16),
            _ThemeSelector(
              value: _theme,
              onChanged: (p) => setState(() => _theme = p),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: AppTypography.errMsg.copyWith(color: t.ink)),
        ],
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: DossierButton(
            label: _isEdit ? 'Save' : 'Create config',
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemePreference value;
  final ValueChanged<ThemePreference> onChanged;

  const _ThemeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final pref in ThemePreference.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DossierButton(
              label: themePreferenceToString(pref),
              visual: pref == value
                  ? DossierButtonVisual.active
                  : DossierButtonVisual.idle,
              onPressed: () => onChanged(pref),
            ),
          ),
      ],
    );
  }
}
