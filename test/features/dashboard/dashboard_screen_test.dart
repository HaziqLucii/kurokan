import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/app.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/features/uptime/domain/monitor_source.dart';
import 'package:kurokan/features/uptime/domain/monitor_status.dart';
import 'package:kurokan/features/uptime/presentation/monitors_provider.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';
import 'package:kurokan/features/vps/domain/vitals_source.dart';
import 'package:kurokan/features/vps/presentation/vitals_provider.dart';

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

class _FakeVitalsSource implements VitalsSource {
  final Future<HostVitals> Function() impl;
  _FakeVitalsSource(this.impl);

  @override
  Future<HostVitals> fetch() => impl();
}

HostVitals _okVitals({UsageLevel cpuLevel = UsageLevel.ok}) => HostVitals(
  slug: 'test-server',
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
  required VitalsSource vitals,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(_testConfig()),
      monitorSourceProvider.overrideWithValue(monitors),
      vitalsSourceProvider.overrideWithValue(vitals),
    ],
    child: const App(),
  );
}

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
    final vitals = _FakeVitalsSource(() => Completer<HostVitals>().future);

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
    final vitals = _FakeVitalsSource(() async => _okVitals());

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
    final vitals = _FakeVitalsSource(
      () async => _okVitals(cpuLevel: UsageLevel.crit),
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
      final vitals = _FakeVitalsSource(() async => _okVitals());

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
      final vitals = _FakeVitalsSource(() async => _okVitals());

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
}
