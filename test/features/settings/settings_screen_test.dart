import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/theme/theme.dart';
import 'package:kurokan/features/settings/settings_screen.dart';

import '../../helpers/test_config.dart';

Future<void> _setWindowSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1100, 720));
  tester.view.physicalSize = const Size(1100, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _harness(String configPath) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.dark),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(initial: null, configPath: configPath),
              ),
            ),
            child: const Text('open settings'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('settings_screen_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  testWidgets(
    'filling the form writes the config file and pops back to the caller',
    (tester) async {
      await _setWindowSize(tester);
      final configPath = '${tempDir.path}/config.json';

      await tester.pumpWidget(_harness(configPath));
      await tester.tap(find.text('open settings'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'my-slug');
      await tester.enterText(find.byType(TextField).at(1), 'wd_token');
      await tester.enterText(
        find.byType(TextField).at(2),
        'https://kuma.example.tld',
      );
      await tester.enterText(find.byType(TextField).at(3), 'uk1_key');
      await tester.enterText(find.byType(TextField).at(4), '60');

      await tester.tap(find.text('CREATE CONFIG'));
      await tester.pumpAndSettle();

      expect(find.text('open settings'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);

      final written =
          jsonDecode(File(configPath).readAsStringSync())
              as Map<String, dynamic>;
      final config = AppConfig.fromJson(written, schema: testConfigSchema);
      expect(config.firstHost?.settings['slug'], 'my-slug');
      expect(config.firstHost?.settings['apiToken'], 'wd_token');
      expect(config.firstUptime?.settings['url'], 'https://kuma.example.tld');
      expect(config.firstUptime?.settings['apiKey'], 'uk1_key');
      expect(config.pollInterval, const Duration(seconds: 60));
    },
  );

  testWidgets('the back button pops without writing a file', (tester) async {
    await _setWindowSize(tester);
    final configPath = '${tempDir.path}/config.json';

    await tester.pumpWidget(_harness(configPath));
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('← BACK'));
    await tester.pumpAndSettle();

    expect(find.text('open settings'), findsOneWidget);
    expect(File(configPath).existsSync(), isFalse);
  });
}
