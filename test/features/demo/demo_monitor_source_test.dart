import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/demo/demo_monitor_source.dart';
import 'package:kurokan/features/demo/demo_scenario.dart';
import 'package:kurokan/features/uptime/domain/monitor_status.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 3, 1, 12);

  Future<List<MonitorStatus>> fetchAt(
    DateTime now, {
    DemoScenario scenario = DemoScenario.calm,
  }) => withClock(
    Clock.fixed(now),
    () => DemoMonitorSource(clock: clock, scenario: scenario).fetch(),
  );

  test('fetch() is deterministic for a fixed clock', () async {
    final a = await fetchAt(fixedNow);
    final b = await fetchAt(fixedNow);
    expect(a.map((m) => m.state).toList(), b.map((m) => m.state).toList());
    expect(
      a.map((m) => m.responseTime).toList(),
      b.map((m) => m.responseTime).toList(),
    );
  });

  test('calm scenario: every monitor is up', () async {
    final monitors = await fetchAt(fixedNow);
    expect(monitors, isNotEmpty);
    for (final monitor in monitors) {
      expect(monitor.state, MonitorState.up);
      expect(monitor.responseTime, isNotNull);
    }
  });

  test('incident scenario: exactly the first monitor is down', () async {
    final monitors = await fetchAt(fixedNow, scenario: DemoScenario.incident);
    expect(monitors.first.state, MonitorState.down);
    expect(monitors.first.responseTime, isNull);
    for (final monitor in monitors.skip(1)) {
      expect(monitor.state, MonitorState.up);
    }
  });

  test('incident pins the down monitor regardless of tick', () async {
    for (final offset in [0, 500, 5000]) {
      final monitors = await fetchAt(
        fixedNow.add(Duration(seconds: offset)),
        scenario: DemoScenario.incident,
      );
      expect(monitors.first.state, MonitorState.down);
    }
  });
}
