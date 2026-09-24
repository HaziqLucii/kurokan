import 'dart:math';

import 'package:clock/clock.dart';

import '../uptime/domain/monitor_source.dart';
import '../uptime/domain/monitor_status.dart';
import 'demo_scenario.dart';

final _anchor = DateTime.utc(2026, 1, 1);

class _DemoMonitorDef {
  final String id;
  final String name;
  final String type;
  const _DemoMonitorDef(this.id, this.name, this.type);
}

const _monitors = [
  _DemoMonitorDef('demo-api', 'API', 'HTTP'),
  _DemoMonitorDef('demo-web', 'Website', 'HTTP'),
  _DemoMonitorDef('demo-db', 'Database', 'TCP'),
  _DemoMonitorDef('demo-queue', 'Worker Queue', 'TCP'),
];

class DemoMonitorSource implements MonitorSource {
  final Clock clock;
  final DemoScenario scenario;
  final int seed;

  const DemoMonitorSource({
    required this.clock,
    this.scenario = DemoScenario.calm,
    this.seed = 7,
  });

  @override
  Future<List<MonitorStatus>> fetch() async {
    final tick = clock.now().difference(_anchor).inSeconds;
    return [
      for (var index = 0; index < _monitors.length; index++)
        _statusFor(_monitors[index], index: index, tick: tick),
    ];
  }

  MonitorStatus _statusFor(
    _DemoMonitorDef def, {
    required int index,
    required int tick,
  }) {
    // The incident scenario always pins the first monitor down, regardless
    // of tick, so a screenshot at any fixed clock shows the DOWN row.
    final isIncidentTarget = scenario == DemoScenario.incident && index == 0;
    final rng = Random(seed + index + tick);

    if (isIncidentTarget) {
      return MonitorStatus(
        id: def.id,
        name: def.name,
        type: def.type,
        state: MonitorState.down,
        responseTime: null,
        uptime24h: 0.92,
        certDaysRemaining: 60 + rng.nextInt(30),
        certValid: true,
      );
    }

    final baseMs = 40 + index * 15;
    return MonitorStatus(
      id: def.id,
      name: def.name,
      type: def.type,
      state: MonitorState.up,
      responseTime: Duration(milliseconds: baseMs + rng.nextInt(20)),
      uptime24h: 0.995 + rng.nextDouble() * 0.004,
      certDaysRemaining: 60 + rng.nextInt(30),
      certValid: true,
    );
  }
}
