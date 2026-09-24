@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/app.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/features/demo/demo_config.dart';
import 'package:kurokan/features/demo/demo_host_source.dart';
import 'package:kurokan/features/demo/demo_monitor_source.dart';
import 'package:kurokan/features/demo/demo_scenario.dart';
import 'package:kurokan/features/uptime/presentation/uptime_provider.dart';
import 'package:kurokan/features/vps/presentation/hosts_provider.dart';

final _fixedNow = DateTime.utc(2026, 3, 1, 12);
final _fixedClock = Clock.fixed(_fixedNow);

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required ThemePreference theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(1100, 720));
  tester.view.physicalSize = const Size(1100, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final demo = demoConfig();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(hosts: demo.hosts, uptime: demo.uptime, theme: theme),
        ),
        // 'demo-uptime'/'demo-host' are the fixed ids demoConfig() gives
        // its entries.
        uptimeSourceProvider('demo-uptime').overrideWithValue(
          DemoMonitorSource(
            clock: _fixedClock,
            scenario: DemoScenario.incident,
          ),
        ),
        hostsSourceProvider('demo-host').overrideWithValue(
          DemoHostSource(clock: _fixedClock, scenario: DemoScenario.incident),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('dashboard, incident scenario, dark theme', (tester) async {
    await withClock(
      _fixedClock,
      () => _pumpDashboard(tester, theme: ThemePreference.dark),
    );
    await expectLater(
      find.byType(App),
      matchesGoldenFile('dashboard_dark.png'),
    );
  });

  testWidgets('dashboard, incident scenario, light theme', (tester) async {
    await withClock(
      _fixedClock,
      () => _pumpDashboard(tester, theme: ThemePreference.light),
    );
    await expectLater(
      find.byType(App),
      matchesGoldenFile('dashboard_light.png'),
    );
  });
}
