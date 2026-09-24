import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/app.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/core/net/fetch_error.dart';
import 'package:kurokan/features/uptime/domain/monitor_source.dart';
import 'package:kurokan/features/uptime/domain/monitor_status.dart';
import 'package:kurokan/features/uptime/presentation/monitor_panel.dart';
import 'package:kurokan/features/uptime/presentation/uptime_provider.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';
import 'package:kurokan/features/vps/domain/hosts_source.dart';
import 'package:kurokan/features/vps/presentation/host_table_panel.dart';
import 'package:kurokan/features/vps/presentation/hosts_provider.dart';
import 'package:kurokan/features/vps/presentation/vitals_panel.dart';

import '../../helpers/test_config.dart';

AppConfig _testConfig() => testConfig(
  webdockSlug: 'test-server',
  webdockToken: 'wd_test',
  kumaUrl: 'https://kuma.test',
  kumaApiKey: 'uk1_test',
  pollInterval: const Duration(seconds: 30),
);

class _FakeMonitorSource implements MonitorSource {
  final Future<List<MonitorStatus>> Function() impl;
  _FakeMonitorSource(this.impl);

  @override
  Future<List<MonitorStatus>> fetch() => impl();
}

class _FakeHostsSource implements HostsSource {
  final Future<List<HostVitals>> Function() impl;
  _FakeHostsSource(this.impl);

  @override
  Future<List<HostVitals>> fetch() => impl();
}

HostVitals _okVitals({
  UsageLevel cpuLevel = UsageLevel.ok,
  String slug = 'test-server',
}) => HostVitals(
  slug: slug,
  name: 'Test Server',
  status: 'running',
  ipv4: '1.2.3.4',
  cpu: Gauge(
    used: 10,
    allowed: 100,
    percentUsed: 10,
    level: cpuLevel,
    unit: 'CPU-s',
  ),
  memory: const Gauge(
    used: 10,
    allowed: 100,
    percentUsed: 10,
    level: UsageLevel.ok,
    unit: 'MiB',
  ),
  disk: const Gauge(
    used: 10,
    allowed: 100,
    percentUsed: 10,
    level: UsageLevel.ok,
    unit: 'MiB',
  ),
  network: const Gauge(
    used: 1,
    allowed: 100,
    percentUsed: 1,
    level: UsageLevel.ok,
    unit: 'GiB',
  ),
  processCount: 10,
  sampledAt: DateTime(2026, 1, 1),
);

Widget _harness({
  required MonitorSource monitors,
  required HostsSource vitals,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig()),
      // 'kuma'/'webdock' are the fixed ids testConfig() gives its entries.
      uptimeSourceProvider('kuma').overrideWithValue(monitors),
      hostsSourceProvider('webdock').overrideWithValue(vitals),
    ],
    child: const App(),
  );
}

Future<void> _setWindowSize(
  WidgetTester tester, {
  Size size = const Size(1100, 720),
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Unmounts the widget tree so every provider's onDispose (including the
/// polling Timer in core/polling/polled.dart) runs before the test body
/// returns — otherwise a pending Timer fails the test as a leak.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('LAST reads --:--:-- before the first fetch resolves', (
    tester,
  ) async {
    await _setWindowSize(tester);
    final monitors = _FakeMonitorSource(
      () => Completer<List<MonitorStatus>>().future,
    );
    final vitals = _FakeHostsSource(() => Completer<List<HostVitals>>().future);

    await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
    await tester.pump();

    expect(find.text('LAST --:--:--'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('a down monitor renders in the inverted DOWN row', (
    tester,
  ) async {
    await _setWindowSize(tester);
    final monitors = _FakeMonitorSource(
      () async => [
        const MonitorStatus(
          id: '1',
          name: 'Up Service',
          type: 'http',
          state: MonitorState.up,
        ),
        const MonitorStatus(
          id: '2',
          name: 'Down Service',
          type: 'http',
          state: MonitorState.down,
        ),
      ],
    );
    final vitals = _FakeHostsSource(() async => [_okVitals()]);

    await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
    await tester.pumpAndSettle();

    expect(find.text('DOWN'), findsOneWidget);
    expect(find.text('Down Service'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('a crit vitals tile renders inverted with the CRIT label', (
    tester,
  ) async {
    await _setWindowSize(tester);
    final monitors = _FakeMonitorSource(
      () async => const [
        MonitorStatus(
          id: '1',
          name: 'Up Service',
          type: 'http',
          state: MonitorState.up,
        ),
      ],
    );
    final vitals = _FakeHostsSource(
      () async => [_okVitals(cpuLevel: UsageLevel.crit)],
    );

    await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
    await tester.pumpAndSettle();

    expect(find.textContaining('CRIT'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
    'an error after a value shows the stale footer, not the error footer',
    (tester) async {
      await _setWindowSize(tester);
      var callCount = 0;
      final monitors = _FakeMonitorSource(() async {
        callCount++;
        if (callCount == 1) {
          return const [
            MonitorStatus(
              id: '1',
              name: 'Up Service',
              type: 'http',
              state: MonitorState.up,
            ),
          ];
        }
        throw Exception('network down');
      });
      final vitals = _FakeHostsSource(() async => [_okVitals()]);

      await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
      await tester.pumpAndSettle();
      // Both panels are freshly fetched at this point.
      expect(find.textContaining('FETCHED'), findsNWidgets(2));
      expect(find.textContaining('STALE'), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      // Monitors goes stale; Vitals (still succeeding) stays fresh.
      expect(find.textContaining('STALE'), findsOneWidget);
      expect(find.textContaining('FETCHED'), findsOneWidget);
      // Still shows the last-known-good row, not an error block replacing it.
      expect(find.text('Up Service'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'manual refresh (⌘R button) is throttled to one trigger per 5 seconds',
    (tester) async {
      await _setWindowSize(tester);
      var monitorFetchCount = 0;
      final monitors = _FakeMonitorSource(() async {
        monitorFetchCount++;
        return const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ];
      });
      final vitals = _FakeHostsSource(() async => [_okVitals()]);

      await withClock(Clock.fixed(DateTime(2026, 1, 1, 12, 0, 0)), () async {
        await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
        await tester.pumpAndSettle();
      });
      expect(monitorFetchCount, 1);

      // Two taps at the same simulated instant: the second must be dropped.
      await withClock(Clock.fixed(DateTime(2026, 1, 1, 12, 0, 1)), () async {
        await tester.tap(find.text('↻ REFRESH'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('↻ REFRESH'));
        await tester.pumpAndSettle();
      });
      expect(monitorFetchCount, 2);

      // A tap 6 simulated seconds later is past the cooldown and triggers again.
      await withClock(Clock.fixed(DateTime(2026, 1, 1, 12, 0, 7)), () async {
        await tester.tap(find.text('↻ REFRESH'));
        await tester.pumpAndSettle();
      });
      expect(monitorFetchCount, 3);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a config with two hosts stacks both host panels in the narrow column',
    (tester) async {
      await _setWindowSize(tester);
      const config = AppConfig(
        hosts: [
          SourceEntry(
            kind: SourceKind.host,
            id: 'webdock',
            provider: 'webdock',
            settings: {'slug': 'test-server', 'apiToken': 'wd_test'},
          ),
          SourceEntry(
            kind: SourceKind.host,
            id: 'webdock2',
            provider: 'webdock',
            settings: {'slug': 'second-server', 'apiToken': 'wd_test'},
          ),
        ],
        uptime: [
          SourceEntry(
            kind: SourceKind.uptime,
            id: 'kuma',
            provider: 'kuma',
            settings: {'url': 'https://kuma.test', 'apiKey': 'uk1_test'},
          ),
        ],
      );
      final monitors = _FakeMonitorSource(
        () async => const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ],
      );
      final vitalsA = _FakeHostsSource(
        () async => [_okVitals(slug: 'first-server')],
      );
      final vitalsB = _FakeHostsSource(
        () async => [_okVitals(slug: 'second-server')],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            uptimeSourceProvider('kuma').overrideWithValue(monitors),
            hostsSourceProvider('webdock').overrideWithValue(vitalsA),
            hostsSourceProvider('webdock2').overrideWithValue(vitalsB),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      // Each host panel renders its own source's slug: this fails if the
      // second panel were accidentally wired to the first host's provider
      // instead of its own (a two-panel test using identical fake data on
      // both sides wouldn't catch that).
      expect(find.text('first-server'), findsOneWidget);
      expect(find.text('second-server'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a source that fails on the very first fetch shows the error body '
    'with the provider tag, not a silent retry',
    (tester) async {
      await _setWindowSize(tester);
      final monitors = _FakeMonitorSource(
        () async => throw const NetworkError('connection refused'),
      );
      final vitals = _FakeHostsSource(() async => [_okVitals()]);

      await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'NETWORK · connection refused · CHECK KUMA CONNECTIVITY',
        ),
        findsOneWidget,
      );

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a host source that fails on the very first fetch shows the error '
    'body with the provider tag, not a silent retry',
    (tester) async {
      await _setWindowSize(tester);
      final monitors = _FakeMonitorSource(
        () async => const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ],
      );
      final vitals = _FakeHostsSource(
        () async => throw const AuthError(401, 'ignored'),
      );

      await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('AUTH · 401 FROM WEBDOCK · CHECK CREDENTIALS'),
        findsOneWidget,
      );

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a host provider missing from the registry falls back to its raw id, '
    'uppercased, as the panel tag',
    (tester) async {
      await _setWindowSize(tester);
      const config = AppConfig(
        hosts: [
          SourceEntry(
            kind: SourceKind.host,
            id: 'mystery',
            provider: 'mystery-provider',
            settings: {},
          ),
        ],
        uptime: [
          SourceEntry(
            kind: SourceKind.uptime,
            id: 'kuma',
            provider: 'kuma',
            settings: {'url': 'https://kuma.test', 'apiKey': 'uk1_test'},
          ),
        ],
      );
      final monitors = _FakeMonitorSource(
        () async => const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ],
      );
      final vitals = _FakeHostsSource(() async => [_okVitals()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            uptimeSourceProvider('kuma').overrideWithValue(monitors),
            hostsSourceProvider('mystery').overrideWithValue(vitals),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MYSTERY-PROVIDER'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'an uptime provider missing from the registry falls back to its raw '
    'id, uppercased, in the first-fetch-error message',
    (tester) async {
      await _setWindowSize(tester);
      const config = AppConfig(
        hosts: [
          SourceEntry(
            kind: SourceKind.host,
            id: 'webdock',
            provider: 'webdock',
            settings: {'slug': 'test-server', 'apiToken': 'wd_test'},
          ),
        ],
        uptime: [
          SourceEntry(
            kind: SourceKind.uptime,
            id: 'mystery',
            provider: 'mystery-provider',
            settings: {},
          ),
        ],
      );
      final monitors = _FakeMonitorSource(
        () async => throw const NetworkError('connection refused'),
      );
      final vitals = _FakeHostsSource(() async => [_okVitals()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            uptimeSourceProvider('mystery').overrideWithValue(monitors),
            hostsSourceProvider('webdock').overrideWithValue(vitals),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('CHECK MYSTERY-PROVIDER CONNECTIVITY'),
        findsOneWidget,
      );

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a host source that goes stale after one good fetch shows the stale '
    'footer for that panel specifically, not the error footer',
    (tester) async {
      await _setWindowSize(tester);
      final monitors = _FakeMonitorSource(
        () async => const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ],
      );
      var callCount = 0;
      final vitals = _FakeHostsSource(() async {
        callCount++;
        if (callCount == 1) return [_okVitals()];
        throw const NetworkError('timeout');
      });

      await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
      await tester.pumpAndSettle();
      expect(find.textContaining('FETCHED'), findsNWidgets(2));
      expect(find.textContaining('STALE'), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      // Vitals goes stale; Monitors (still succeeding) stays fresh: the
      // mirror image of the existing "monitors goes stale" case above.
      expect(find.textContaining('STALE'), findsOneWidget);
      expect(find.textContaining('FETCHED'), findsOneWidget);

      await _disposeTree(tester);
    },
  );

  testWidgets('a host source that returns zero hosts renders the empty-hosts '
      'placeholder instead of crashing on .first', (tester) async {
    await _setWindowSize(tester);
    final monitors = _FakeMonitorSource(
      () async => const [
        MonitorStatus(
          id: '1',
          name: 'Up Service',
          type: 'http',
          state: MonitorState.up,
        ),
      ],
    );
    final vitals = _FakeHostsSource(() async => <HostVitals>[]);

    await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
    await tester.pumpAndSettle();

    expect(find.text('NO HOST DATA'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets(
    'below the layout breakpoint, panels stack single-column with the '
    'uptime panel above the vitals panel',
    (tester) async {
      await _setWindowSize(tester, size: const Size(800, 1400));
      final monitors = _FakeMonitorSource(
        () async => const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ],
      );
      final vitals = _FakeHostsSource(() async => [_okVitals()]);

      await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
      await tester.pumpAndSettle();

      final uptimeTop = tester.getTopLeft(find.byType(MonitorPanel)).dy;
      final vitalsTop = tester.getTopLeft(find.byType(VitalsPanel)).dy;
      expect(uptimeTop, lessThan(vitalsTop));

      await _disposeTree(tester);
    },
  );

  testWidgets(
    'a host source that yields several hosts in one fetch renders the '
    'compact host table instead of the single-host detail view',
    (tester) async {
      await _setWindowSize(tester);
      final monitors = _FakeMonitorSource(
        () async => const [
          MonitorStatus(
            id: '1',
            name: 'Up Service',
            type: 'http',
            state: MonitorState.up,
          ),
        ],
      );
      final vitals = _FakeHostsSource(
        () async => [_okVitals(slug: 'fleet-a'), _okVitals(slug: 'fleet-b')],
      );

      await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
      await tester.pumpAndSettle();

      expect(find.byType(HostTablePanel), findsOneWidget);
      expect(find.text('Test Server'), findsNWidgets(2));

      await _disposeTree(tester);
    },
  );

  testWidgets('a host missing memory/disk/network gauges renders "—" for those '
      'tiles instead of crashing (a provider that cannot report them)', (
    tester,
  ) async {
    await _setWindowSize(tester);
    final monitors = _FakeMonitorSource(
      // responseTime/uptime24h are set so this monitor row renders no "—"
      // of its own: the count below isolates the vitals fallback tiles.
      () async => const [
        MonitorStatus(
          id: '1',
          name: 'Up Service',
          type: 'http',
          state: MonitorState.up,
          responseTime: Duration(milliseconds: 42),
          uptime24h: 0.999,
        ),
      ],
    );
    final vitals = _FakeHostsSource(
      () async => [
        HostVitals(
          slug: 'bare-metal',
          name: 'Bare Metal',
          status: 'running',
          ipv4: '1.2.3.4',
          cpu: const Gauge(
            used: 10,
            allowed: 100,
            percentUsed: 10,
            level: UsageLevel.ok,
            unit: '%',
          ),
          memory: null,
          disk: null,
          network: null,
          processCount: null,
          sampledAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(_harness(monitors: monitors, vitals: vitals));
    await tester.pumpAndSettle();

    expect(find.text('MEM'), findsOneWidget);
    expect(find.text('DISK'), findsOneWidget);
    expect(find.text('NETWORK'), findsOneWidget);
    // StatTile's number is a RichText, not a plain Text: find.text() only
    // matches it with findRichText: true, otherwise this would only prove
    // the unrelated Procs row (processCount: null) shows "—", not that the
    // Mem/Disk/Network tiles' own fallback actually rendered anything.
    // 3 unavailable tiles x (number + sub) + the Procs row = 7.
    expect(find.text('—', findRichText: true), findsNWidgets(7));

    await _disposeTree(tester);
  });
}
