import 'dart:math';

import 'package:clock/clock.dart';

import '../containers/domain/container_status.dart';
import 'demo_scenario.dart';

final _anchor = DateTime.utc(2026, 1, 1);

class DemoContainerSource implements ContainerSource {
  final Clock clock;
  final DemoScenario scenario;
  final int seed;

  const DemoContainerSource({
    required this.clock,
    this.scenario = DemoScenario.calm,
    this.seed = 1,
  });

  @override
  Future<List<ContainerStatus>> fetch() async {
    final now = clock.now();
    final tick = now.difference(_anchor).inSeconds;
    final incident = scenario == DemoScenario.incident;

    return [
      ContainerStatus(
        id: 'demo-web',
        name: 'web',
        image: 'nginx:alpine',
        state: ContainerState.running,
        health: incident ? HealthState.unhealthy : HealthState.healthy,
        restartCount: incident ? 3 : 0,
        cpuPercent: _wave(
          tick: tick,
          base: 8,
          amplitude: 6,
          period: 45,
          seedOffset: 0,
        ),
        memUsed: 48 * 1024 * 1024,
        memLimit: 512 * 1024 * 1024,
        startedAt: now.subtract(const Duration(hours: 6, minutes: 12)),
      ),
      ContainerStatus(
        id: 'demo-worker',
        name: 'worker',
        image: 'kurokan/worker:1.4.0',
        state: ContainerState.running,
        health: HealthState.none,
        restartCount: 0,
        cpuPercent: _wave(
          tick: tick,
          base: 22,
          amplitude: 15,
          period: 60,
          seedOffset: 1,
        ),
        memUsed: 190 * 1024 * 1024,
        memLimit: 512 * 1024 * 1024,
        startedAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
      ContainerStatus(
        id: 'demo-cache',
        name: 'cache',
        image: 'redis:7-alpine',
        state: ContainerState.running,
        health: HealthState.starting,
        restartCount: 0,
        cpuPercent: _wave(
          tick: tick,
          base: 3,
          amplitude: 2,
          period: 30,
          seedOffset: 2,
        ),
        memUsed: 12 * 1024 * 1024,
        memLimit: 256 * 1024 * 1024,
        startedAt: now.subtract(const Duration(minutes: 4)),
      ),
      ContainerStatus(
        id: 'demo-migrate',
        name: 'migrate',
        image: 'kurokan/migrate:1.4.0',
        state: ContainerState.exited,
        health: HealthState.none,
        restartCount: 0,
        cpuPercent: null,
        memUsed: null,
        memLimit: null,
        startedAt: now.subtract(const Duration(days: 2, hours: 3, minutes: 1)),
      ),
    ];
  }

  double _wave({
    required int tick,
    required double base,
    required double amplitude,
    required int period,
    required int seedOffset,
  }) {
    final rng = Random(seed + seedOffset + tick);
    final value = base + amplitude * sin(tick / period);
    final jitter = (rng.nextDouble() - 0.5) * 2 * (amplitude * 0.15);
    return (value + jitter).clamp(0, 100);
  }
}
