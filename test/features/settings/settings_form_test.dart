import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/core/theme/theme.dart';
import 'package:kurokan/features/settings/settings_form.dart';

import '../../helpers/test_config.dart';

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
      expect(saved!.firstHost?.settings['slug'], 'my-slug');
      expect(saved!.firstHost?.settings['apiToken'], 'wd_token');
      expect(saved!.firstUptime?.settings['url'], 'https://kuma.example.tld');
      expect(saved!.firstUptime?.settings['apiKey'], 'uk1_key');
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
    final initial = testConfig(
      webdockSlug: 'old-slug',
      webdockToken: 'old-token',
      kumaUrl: 'https://old.kuma.tld',
      kumaApiKey: 'old-key',
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
    expect(saved!.firstHost?.settings['slug'], 'new-slug');
    expect(saved!.firstHost?.settings['apiToken'], 'old-token');
    expect(saved!.firstUptime?.settings['apiKey'], 'old-key');
  });

  testWidgets('edit mode: clearing the slug still blocks save', (tester) async {
    final initial = testConfig(
      webdockSlug: 'old-slug',
      webdockToken: 'old-token',
      kumaUrl: 'https://old.kuma.tld',
      kumaApiKey: 'old-key',
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
    final initial = testConfig(
      webdockSlug: 'old-slug',
      webdockToken: 'old-token',
      kumaUrl: 'https://old.kuma.tld',
      kumaApiKey: 'old-key',
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

    expect(saved!.firstHost?.settings['apiToken'], 'brand-new-token');
  });

  testWidgets('edit mode: save preserves everything the form does not edit', (
    tester,
  ) async {
    final initial = AppConfig(
      hosts: [
        const SourceEntry(
          kind: SourceKind.host,
          id: 'my-vps',
          provider: 'webdock',
          settings: {'slug': 'old-slug', 'apiToken': 'old-token'},
        ),
        const SourceEntry(
          kind: SourceKind.host,
          id: 'second-host',
          provider: 'webdock',
          settings: {'slug': 'second-slug', 'apiToken': 'second-token'},
        ),
      ],
      uptime: [
        const SourceEntry(
          kind: SourceKind.uptime,
          id: 'my-kuma',
          provider: 'kuma',
          settings: {'url': 'https://old.kuma.tld', 'apiKey': 'old-key'},
        ),
      ],
      containers: const [
        SourceEntry(
          kind: SourceKind.containers,
          id: 'docker',
          provider: 'docker',
          settings: {'endpoint': 'unix:///var/run/docker.sock'},
        ),
      ],
      history: const HistoryConfig(retention: Duration.zero),
      notifications: const NotificationsConfig(enabled: true),
      layout: const LayoutConfig(order: ['uptime:my-kuma'], incidents: false),
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

    await tester.enterText(_fieldAt(0), 'new-slug');
    await tester.tap(find.text('SAVE'));
    await tester.pump();

    expect(saved, isNotNull);
    // The edited entry keeps its original id/provider.
    expect(saved!.hosts.first.id, 'my-vps');
    expect(saved!.hosts.first.settings['slug'], 'new-slug');
    // Everything else the form doesn't touch survives verbatim.
    expect(saved!.hosts.length, 2);
    expect(saved!.hosts[1].id, 'second-host');
    expect(saved!.containers.length, 1);
    expect(saved!.containers.first.id, 'docker');
    expect(saved!.history.retention, Duration.zero);
    expect(saved!.notifications.enabled, isTrue);
    expect(saved!.layout.order, ['uptime:my-kuma']);
    expect(saved!.layout.incidents, isFalse);
  });
}
