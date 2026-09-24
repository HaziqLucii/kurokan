import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';

void main() {
  group('Gauge.fromUsedAllowed', () {
    test('computes percent and an ok level well below warnAt', () {
      final gauge = Gauge.fromUsedAllowed(10, 100, unit: '%');

      expect(gauge.used, 10);
      expect(gauge.allowed, 100);
      expect(gauge.percentUsed, 10);
      expect(gauge.level, UsageLevel.ok);
    });

    test('boundary: exactly at warnAt is warn, exactly at critAt is crit', () {
      final atWarn = Gauge.fromUsedAllowed(80, 100, unit: '%');
      final justBelowWarn = Gauge.fromUsedAllowed(79.999, 100, unit: '%');
      final atCrit = Gauge.fromUsedAllowed(95, 100, unit: '%');
      final justBelowCrit = Gauge.fromUsedAllowed(94.999, 100, unit: '%');

      expect(atWarn.level, UsageLevel.warn);
      expect(justBelowWarn.level, UsageLevel.ok);
      expect(atCrit.level, UsageLevel.crit);
      expect(justBelowCrit.level, UsageLevel.warn);
    });

    test('honors per-kind warnAt/critAt overrides (disk 70/90)', () {
      final atDiskWarn = Gauge.fromUsedAllowed(
        70,
        100,
        unit: '%',
        warnAt: 70,
        critAt: 90,
      );
      final atDiskCrit = Gauge.fromUsedAllowed(
        90,
        100,
        unit: '%',
        warnAt: 70,
        critAt: 90,
      );

      expect(atDiskWarn.level, UsageLevel.warn);
      expect(atDiskCrit.level, UsageLevel.crit);
    });

    test(
      'a null allowed (unbounded resource) yields no percent and an ok level',
      () {
        final gauge = Gauge.fromUsedAllowed(500, null, unit: 'GiB');

        expect(gauge.used, 500);
        expect(gauge.allowed, isNull);
        expect(gauge.percentUsed, isNull);
        expect(gauge.level, UsageLevel.ok);
      },
    );

    test('a zero allowed yields no percent instead of dividing by zero', () {
      final gauge = Gauge.fromUsedAllowed(5, 0, unit: '%');

      expect(gauge.percentUsed, isNull);
      expect(gauge.level, UsageLevel.ok);
    });

    test('a NaN allowed yields no percent instead of a NaN percent', () {
      final gauge = Gauge.fromUsedAllowed(5, double.nan, unit: '%');

      expect(gauge.percentUsed, isNull);
      expect(gauge.level, UsageLevel.ok);
    });

    test('a NaN used yields no percent instead of a NaN percent', () {
      final gauge = Gauge.fromUsedAllowed(double.nan, 100, unit: '%');

      expect(gauge.percentUsed, isNull);
      expect(gauge.level, UsageLevel.ok);
    });
  });
}
