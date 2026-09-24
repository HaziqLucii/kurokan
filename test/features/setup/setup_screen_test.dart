import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/providers/default_registry.dart';
import 'package:kurokan/features/setup/setup_screen.dart';

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

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('setup_screen_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('"Try with demo data" writes a loadable demo config', (
    tester,
  ) async {
    await _setWindowSize(tester);
    final configPath = '${tempDir.path}/config.json';

    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          configPath: configPath,
          error: null,
          onOpenFolder: () {},
        ),
      ),
    );

    await tester.tap(find.text('TRY WITH DEMO DATA'));
    await tester.pump();

    expect(File(configPath).existsSync(), isTrue);

    final written =
        jsonDecode(File(configPath).readAsStringSync()) as Map<String, dynamic>;
    final config = AppConfig.fromJson(written, schema: defaultRegistry);
    expect(config.firstHost?.provider, 'demo');
    expect(config.firstUptime?.provider, 'demo');
  });

  testWidgets(
    '"Try with demo data" is hidden when the existing config is invalid, '
    'not just missing',
    (tester) async {
      await _setWindowSize(tester);
      final configPath = '${tempDir.path}/config.json';
      // A real file with a typo could hold real credentials; the button
      // must never risk silently overwriting it.
      File(configPath).writeAsStringSync('{not valid json');

      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            configPath: configPath,
            error: const ConfigError(
              '/tmp/config.json',
              'invalid JSON: unexpected character',
            ),
            onOpenFolder: () {},
          ),
        ),
      );

      expect(find.text('TRY WITH DEMO DATA'), findsNothing);
      expect(find.text('SET UP NOW'), findsOneWidget);
    },
  );

  testWidgets(
    '"Try with demo data" is shown when the config is simply not found',
    (tester) async {
      await _setWindowSize(tester);
      final configPath = '${tempDir.path}/config.json';

      await tester.pumpWidget(
        MaterialApp(
          home: SetupScreen(
            configPath: configPath,
            error: const ConfigError(
              '/tmp/config.json',
              'not found',
              notFound: true,
            ),
            onOpenFolder: () {},
          ),
        ),
      );

      expect(find.text('TRY WITH DEMO DATA'), findsOneWidget);
    },
  );
}
