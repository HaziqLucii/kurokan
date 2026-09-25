import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/containers/domain/container_status.dart';
import 'package:kurokan/features/demo/demo_container_source.dart';
import 'package:kurokan/features/demo/demo_scenario.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 3, 1, 12);

  Future<List<ContainerStatus>> fetchAt(
    DateTime now, {
    DemoScenario scenario = DemoScenario.calm,
  }) => withClock(
    Clock.fixed(now),
    () => DemoContainerSource(clock: clock, scenario: scenario).fetch(),
  );

  test('fetch() is deterministic for a fixed clock', () async {
    final a = await fetchAt(fixedNow);
    final b = await fetchAt(fixedNow);

    expect(
      a.map((c) => c.cpuPercent).toList(),
      b.map((c) => c.cpuPercent).toList(),
    );
    expect(a.map((c) => c.name).toList(), b.map((c) => c.name).toList());
  });

  test('yields more than one container, so the compact table view has '
      'something real to show once it lands', () async {
    final containers = await fetchAt(fixedNow);
    expect(containers.length, greaterThan(1));
  });

  test('every cpuPercent stays within 0-100 when present', () async {
    for (final offset in [0, 500, 5000, 50000]) {
      final containers = await fetchAt(fixedNow.add(Duration(seconds: offset)));
      for (final c in containers) {
        if (c.cpuPercent != null) {
          expect(c.cpuPercent, inInclusiveRange(0, 100));
        }
      }
    }
  });

  test('calm scenario has no unhealthy container and no restarts', () async {
    for (final offset in [0, 500, 5000, 50000]) {
      final containers = await fetchAt(fixedNow.add(Duration(seconds: offset)));
      for (final c in containers) {
        expect(c.health, isNot(HealthState.unhealthy));
        expect(c.restartCount, 0);
      }
    }
  });

  test('incident scenario pins one container unhealthy with restarts, '
      'regardless of tick', () async {
    for (final offset in [0, 500, 5000]) {
      final containers = await fetchAt(
        fixedNow.add(Duration(seconds: offset)),
        scenario: DemoScenario.incident,
      );
      expect(
        containers.any(
          (c) => c.health == HealthState.unhealthy && c.restartCount > 0,
        ),
        isTrue,
      );
    }
  });

  test('at least one container is always exited, with null gauges', () async {
    final containers = await fetchAt(fixedNow);
    final exited = containers.where((c) => c.state == ContainerState.exited);
    expect(exited, isNotEmpty);
    for (final c in exited) {
      expect(c.cpuPercent, isNull);
      expect(c.memUsed, isNull);
    }
  });
}
