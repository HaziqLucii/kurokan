import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/demo/demo_host_source.dart';
import 'package:kurokan/features/demo/demo_scenario.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 3, 1, 12);

  Future<HostVitals> fetchAt(
    DateTime now, {
    DemoScenario scenario = DemoScenario.calm,
  }) => withClock(
    Clock.fixed(now),
    () async =>
        (await DemoHostSource(clock: clock, scenario: scenario).fetch()).single,
  );

  test('fetch() is deterministic for a fixed clock', () async {
    final a = await fetchAt(fixedNow);
    final b = await fetchAt(fixedNow);

    expect(a.cpu.percentUsed, b.cpu.percentUsed);
    expect(a.memory!.percentUsed, b.memory!.percentUsed);
    expect(a.disk!.percentUsed, b.disk!.percentUsed);
    expect(a.network!.percentUsed, b.network!.percentUsed);
    expect(a.processCount, b.processCount);
  });

  test('every gauge percent stays within 0-100', () async {
    for (final offset in [0, 10, 100, 1000, 50000]) {
      final vitals = await fetchAt(fixedNow.add(Duration(seconds: offset)));
      // DemoHostSource always populates every gauge; the ! below asserts
      // that guarantee, same as this repo's other "safe on the app's
      // actual path" non-null assertions (see docs/DECISIONS.md Phase 1.2).
      for (final gauge in [
        vitals.cpu,
        vitals.memory!,
        vitals.disk!,
        vitals.network!,
      ]) {
        expect(gauge.percentUsed, inInclusiveRange(0, 100));
      }
    }
  });

  test('calm scenario never reaches crit', () async {
    for (final offset in [0, 500, 5000, 50000]) {
      final vitals = await fetchAt(fixedNow.add(Duration(seconds: offset)));
      for (final gauge in [
        vitals.cpu,
        vitals.memory!,
        vitals.disk!,
        vitals.network!,
      ]) {
        expect(gauge.level, isNot(UsageLevel.crit));
      }
    }
  });

  test(
    'incident scenario pins the CPU gauge to crit regardless of tick',
    () async {
      for (final offset in [0, 500, 5000]) {
        final vitals = await fetchAt(
          fixedNow.add(Duration(seconds: offset)),
          scenario: DemoScenario.incident,
        );
        expect(vitals.cpu.percentUsed, 97.0);
        expect(vitals.cpu.level, UsageLevel.crit);
      }
    },
  );

  test('sampledAt matches the clock', () async {
    final vitals = await fetchAt(fixedNow);
    expect(vitals.sampledAt, fixedNow);
  });
}
