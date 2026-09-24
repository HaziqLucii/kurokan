import 'dart:math';

import 'package:clock/clock.dart';

import '../vps/domain/host_vitals.dart';
import '../vps/domain/hosts_source.dart';
import 'demo_scenario.dart';

/// Anchor for the tick counter: `demo_wave` values are a pure function of
/// elapsed seconds since this instant, never of wall-clock "now" directly,
/// so a fixed [Clock] (as goldens use) always reproduces the same output.
final _anchor = DateTime.utc(2026, 1, 1);

class DemoHostSource implements HostsSource {
  final Clock clock;
  final DemoScenario scenario;
  final int seed;

  const DemoHostSource({
    required this.clock,
    this.scenario = DemoScenario.calm,
    this.seed = 1,
  });

  @override
  Future<List<HostVitals>> fetch() async {
    final now = clock.now();
    final tick = now.difference(_anchor).inSeconds;

    final cpuPercent = scenario == DemoScenario.incident
        ? 97.0
        : _wave(
            tick: tick,
            base: 35,
            amplitude: 20,
            period: 40,
            noise: 4,
            seedOffset: 0,
          );
    final memPercent = _wave(
      tick: tick,
      base: 55,
      amplitude: 15,
      period: 65,
      noise: 3,
      seedOffset: 1,
    );
    final diskPercent = _wave(
      tick: tick,
      base: 42,
      amplitude: 4,
      period: 300,
      noise: 1,
      seedOffset: 2,
    );
    final netPercent = _wave(
      tick: tick,
      base: 25,
      amplitude: 12,
      period: 50,
      noise: 5,
      seedOffset: 3,
    );

    return [
      HostVitals(
        slug: 'demo-vps',
        name: 'Demo VPS',
        status: 'running',
        ipv4: '203.0.113.10',
        cpu: _gauge(cpuPercent, unit: 'CPU-s'),
        memory: _gauge(memPercent, unit: 'MiB'),
        disk: _gauge(diskPercent, unit: 'MiB', warnAt: 70, critAt: 90),
        network: _gauge(netPercent, unit: 'GiB'),
        processCount: 80 + (tick % 15),
        sampledAt: now,
      ),
    ];
  }

  double _wave({
    required int tick,
    required double base,
    required double amplitude,
    required int period,
    required double noise,
    required int seedOffset,
  }) {
    final rng = Random(seed + seedOffset + tick);
    final value = base + amplitude * sin(tick / period);
    final jitter = (rng.nextDouble() - 0.5) * 2 * noise;
    return (value + jitter).clamp(0, 100);
  }

  Gauge _gauge(
    double percent, {
    required String unit,
    double warnAt = 80,
    double critAt = 95,
  }) => Gauge.fromUsedAllowed(
    percent,
    100,
    unit: unit,
    warnAt: warnAt,
    critAt: critAt,
  );
}
