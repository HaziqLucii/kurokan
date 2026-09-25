import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/theme/theme.dart';
import 'package:kurokan/core/theme/tokens.dart';
import 'package:kurokan/features/containers/domain/container_status.dart';
import 'package:kurokan/features/containers/presentation/container_row.dart';
import 'package:kurokan/shared/widgets/status_glyph.dart';

final _now = DateTime(2026, 1, 1, 12, 0, 0);

ContainerStatus _container({
  ContainerState state = ContainerState.running,
  HealthState health = HealthState.none,
  int restartCount = 0,
  double? cpuPercent = 12,
  int? memUsed = 40 * 1024 * 1024,
  DateTime? startedAt,
}) => ContainerStatus(
  id: 'c',
  name: 'x',
  image: 'img:latest',
  state: state,
  health: health,
  restartCount: restartCount,
  cpuPercent: cpuPercent,
  memUsed: memUsed,
  memLimit: 512 * 1024 * 1024,
  startedAt: startedAt,
);

Future<void> _pump(WidgetTester tester, ContainerStatus container) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: Material(
        child: ContainerRow(container: container, now: _now),
      ),
    ),
  );
}

void main() {
  group('glyph', () {
    final cases = <String, (ContainerState, HealthState, String)>{
      'running + healthy -> up': (
        ContainerState.running,
        HealthState.healthy,
        StatusGlyphs.up,
      ),
      'running + no healthcheck -> up': (
        ContainerState.running,
        HealthState.none,
        StatusGlyphs.up,
      ),
      'running + unhealthy -> down': (
        ContainerState.running,
        HealthState.unhealthy,
        StatusGlyphs.down,
      ),
      'running + starting -> pending': (
        ContainerState.running,
        HealthState.starting,
        StatusGlyphs.pending,
      ),
      'exited -> down': (
        ContainerState.exited,
        HealthState.none,
        StatusGlyphs.down,
      ),
      'dead -> down': (
        ContainerState.dead,
        HealthState.none,
        StatusGlyphs.down,
      ),
      'paused -> muted': (
        ContainerState.paused,
        HealthState.none,
        StatusGlyphs.muted,
      ),
      'restarting -> muted': (
        ContainerState.restarting,
        HealthState.none,
        StatusGlyphs.muted,
      ),
      'created -> muted': (
        ContainerState.created,
        HealthState.none,
        StatusGlyphs.muted,
      ),
      'unknown -> pending': (
        ContainerState.unknown,
        HealthState.none,
        StatusGlyphs.pending,
      ),
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        final (state, health, glyph) = entry.value;
        await _pump(tester, _container(state: state, health: health));
        expect(find.text(glyph), findsOneWidget);
      });
    }
  });

  group('uptime text', () {
    testWidgets('null startedAt renders "—"', (tester) async {
      await _pump(tester, _container(startedAt: null));
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('under a minute renders in seconds', (tester) async {
      await _pump(
        tester,
        _container(startedAt: _now.subtract(const Duration(seconds: 45))),
      );
      expect(find.text('45S'), findsOneWidget);
    });

    testWidgets('under an hour renders in minutes', (tester) async {
      await _pump(
        tester,
        _container(startedAt: _now.subtract(const Duration(minutes: 5))),
      );
      expect(find.text('5M'), findsOneWidget);
    });

    testWidgets('under a day renders in hours', (tester) async {
      await _pump(
        tester,
        _container(startedAt: _now.subtract(const Duration(hours: 6))),
      );
      expect(find.text('6H'), findsOneWidget);
    });

    testWidgets('a day or more renders in days', (tester) async {
      await _pump(
        tester,
        _container(startedAt: _now.subtract(const Duration(days: 2))),
      );
      expect(find.text('2D'), findsOneWidget);
    });
  });

  group('CPU/MEM text', () {
    testWidgets('null cpuPercent/memUsed render "—"', (tester) async {
      await _pump(
        tester,
        _container(
          cpuPercent: null,
          memUsed: null,
          startedAt: _now, // isolate the CPU/MEM dashes from the uptime one
        ),
      );
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('cpuPercent rounds to the nearest integer percent', (
      tester,
    ) async {
      await _pump(tester, _container(cpuPercent: 12.6));
      expect(find.text('13%'), findsOneWidget);
    });

    testWidgets('memUsed renders rounded MB', (tester) async {
      await _pump(tester, _container(memUsed: 48 * 1024 * 1024));
      expect(find.text('48MB'), findsOneWidget);
    });
  });

  group('restart count', () {
    testWidgets('0 restarts renders in the faint (non-amber) color', (
      tester,
    ) async {
      await _pump(tester, _container(restartCount: 0));
      final text = tester.widget<Text>(find.text('0'));
      final t = DesignTokens.dark;
      expect(text.style?.color, t.faint);
    });

    testWidgets('a nonzero restart count renders in amber', (tester) async {
      await _pump(tester, _container(restartCount: 3));
      final text = tester.widget<Text>(find.text('3'));
      expect(text.style?.color, statusWarnColor);
    });
  });
}
