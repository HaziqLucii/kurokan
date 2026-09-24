import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/theme/theme.dart';
import 'package:kurokan/features/settings/settings_form.dart';

Widget _harness({
  required AppConfig? initial,
  required String? Function(AppConfig) onSave,
}) {
  return MaterialApp(
    theme: buildAppTheme(Brightness.dark),
    home: Scaffold(
      body: SettingsForm(initial: initial, onSave: onSave),
    ),
  );
}

Finder _fieldAt(int index) => find.byType(TextField).at(index);

void main() {
  testWidgets('create mode: blank required fields blocks save with an error', (
    tester,
  ) async {
    AppConfig? saved;
    await tester.pumpWidget(
      _harness(
        initial: null,
        onSave: (c) {
          saved = c;
          return null;
        },
      ),
    );

    await tester.tap(find.text('CREATE CONFIG'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.textContaining('required'), findsOneWidget);
  });

  testWidgets('create mode: blank kuma url blocks save with an error', (
    tester,
  ) async {
    AppConfig? saved;
    await tester.pumpWidget(
      _harness(
        initial: null,
        onSave: (c) {
          saved = c;
          return null;
        },
      ),
    );

    await tester.enterText(_fieldAt(0), 'my-slug'); // webdock slug
    await tester.enterText(_fieldAt(1), 'wd_token'); // webdock token
    await tester.enterText(_fieldAt(3), 'uk1_key'); // kuma api key
    await tester.enterText(_fieldAt(4), '60'); // poll interval

    await tester.tap(find.text('CREATE CONFIG'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.textContaining('Kuma url is required'), findsOneWidget);
  });

  testWidgets(
    'create mode: filling every field calls onSave with the typed values',
    (tester) async {
      AppConfig? saved;
      await tester.pumpWidget(
        _harness(
          initial: null,
          onSave: (c) {
            saved = c;
            return null;
          },
        ),
      );

      await tester.enterText(_fieldAt(0), 'my-slug'); // webdock slug
      await tester.enterText(_fieldAt(1), 'wd_token'); // webdock token
      await tester.enterText(
        _fieldAt(2),
        'https://kuma.example.tld',
      ); // kuma url
      await tester.enterText(_fieldAt(3), 'uk1_key'); // kuma api key
      await tester.enterText(_fieldAt(4), '60'); // poll interval

      await tester.tap(find.text('CREATE CONFIG'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.webdock.slug, 'my-slug');
      expect(saved!.webdock.apiToken, 'wd_token');
      expect(saved!.kuma.url, 'https://kuma.example.tld');
      expect(saved!.kuma.apiKey, 'uk1_key');
      expect(saved!.pollInterval, const Duration(seconds: 60));
    },
  );

  testWidgets('poll interval must be a positive number', (tester) async {
    AppConfig? saved;
    await tester.pumpWidget(
      _harness(
        initial: null,
        onSave: (c) {
          saved = c;
          return null;
        },
      ),
    );

    await tester.enterText(_fieldAt(0), 'my-slug');
    await tester.enterText(_fieldAt(1), 'wd_token');
    await tester.enterText(_fieldAt(2), 'https://kuma.example.tld');
    await tester.enterText(_fieldAt(3), 'uk1_key');
    await tester.enterText(_fieldAt(4), '0');

    await tester.tap(find.text('CREATE CONFIG'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.textContaining('positive'), findsOneWidget);
  });

  testWidgets('edit mode: blank secret fields keep the existing secrets', (
    tester,
  ) async {
    const initial = AppConfig(
      webdock: WebdockConfig(slug: 'old-slug', apiToken: 'old-token'),
      kuma: KumaConfig(url: 'https://old.kuma.tld', apiKey: 'old-key'),
      pollInterval: Duration(seconds: 30),
    );
    AppConfig? saved;
    await tester.pumpWidget(
      _harness(
        initial: initial,
        onSave: (c) {
          saved = c;
          return null;
        },
      ),
    );

    // Change only the non-secret slug; leave both secret fields blank.
    await tester.enterText(_fieldAt(0), 'new-slug');

    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.webdock.slug, 'new-slug');
    expect(saved!.webdock.apiToken, 'old-token');
    expect(saved!.kuma.apiKey, 'old-key');
  });

  testWidgets('edit mode: clearing the slug still blocks save', (tester) async {
    const initial = AppConfig(
      webdock: WebdockConfig(slug: 'old-slug', apiToken: 'old-token'),
      kuma: KumaConfig(url: 'https://old.kuma.tld', apiKey: 'old-key'),
    );
    AppConfig? saved;
    await tester.pumpWidget(
      _harness(
        initial: initial,
        onSave: (c) {
          saved = c;
          return null;
        },
      ),
    );

    await tester.enterText(_fieldAt(0), '');

    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.textContaining('Webdock slug is required'), findsOneWidget);
  });

  testWidgets('edit mode: typing a new secret overrides the existing one', (
    tester,
  ) async {
    const initial = AppConfig(
      webdock: WebdockConfig(slug: 'old-slug', apiToken: 'old-token'),
      kuma: KumaConfig(url: 'https://old.kuma.tld', apiKey: 'old-key'),
    );
    AppConfig? saved;
    await tester.pumpWidget(
      _harness(
        initial: initial,
        onSave: (c) {
          saved = c;
          return null;
        },
      ),
    );

    await tester.enterText(_fieldAt(1), 'brand-new-token');

    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(saved!.webdock.apiToken, 'brand-new-token');
  });
}
