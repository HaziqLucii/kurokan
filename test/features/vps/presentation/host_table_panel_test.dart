import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/theme/theme.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';
import 'package:kurokan/features/vps/presentation/host_table_panel.dart';

const _gauge = Gauge(
  used: 10,
  allowed: 100,
  percentUsed: 42,
  level: UsageLevel.ok,
  unit: 'x',
);

HostVitals _host({
  required String slug,
  required String name,
  double cpuPercent = 42,
  double memPercent = 55,
  double diskPercent = 60,
  String status = 'running',
}) => HostVitals(
  slug: slug,
  name: name,
  status: status,
  ipv4: '1.2.3.4',
  cpu: Gauge(
    used: cpuPercent,
    allowed: 100,
    percentUsed: cpuPercent,
    level: UsageLevel.ok,
    unit: '%',
  ),
  memory: Gauge(
    used: memPercent,
    allowed: 100,
    percentUsed: memPercent,
    level: UsageLevel.ok,
    unit: '%',
  ),
  disk: Gauge(
    used: diskPercent,
    allowed: 100,
    percentUsed: diskPercent,
    level: UsageLevel.ok,
    unit: '%',
  ),
  network: _gauge,
  processCount: 1,
  sampledAt: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester, List<HostVitals> hosts) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: Material(child: HostTablePanel(hosts: hosts)),
    ),
  );
}

void main() {
  testWidgets(
    'renders one row per host with its name and rounded percentages',
    (tester) async {
      await _pump(tester, [
        _host(
          slug: 'a',
          name: 'alpha',
          cpuPercent: 12.6,
          memPercent: 55.4,
          diskPercent: 60,
        ),
        _host(
          slug: 'b',
          name: 'beta',
          cpuPercent: 90.2,
          memPercent: 10,
          diskPercent: 33.5,
        ),
      ]);

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      // 12.6 rounds to 13, 90.2 rounds to 90.
      expect(find.text('13%'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('MEM'), findsOneWidget);
      expect(find.text('DISK'), findsOneWidget);
    },
  );

  testWidgets('renders a row for every host, in order, without collapsing', (
    tester,
  ) async {
    final hosts = List.generate(5, (i) => _host(slug: 'h$i', name: 'host-$i'));
    await _pump(tester, hosts);

    for (final host in hosts) {
      expect(find.text(host.name), findsOneWidget);
    }
  });

  testWidgets(
    'a host missing memory/disk gauges shows "—" for those cells, not a crash',
    (tester) async {
      final bare = HostVitals(
        slug: 'bare',
        name: 'bare-metal',
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
      );

      await _pump(tester, [bare, _host(slug: 'a', name: 'alpha')]);

      expect(find.text('bare-metal'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    },
  );
}
