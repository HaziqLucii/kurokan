enum UsageLevel { ok, warn, crit }

class Gauge {
  final double used;
  final double? allowed;
  final double? percentUsed;
  final UsageLevel level;
  final String unit;

  const Gauge({
    required this.used,
    required this.allowed,
    required this.percentUsed,
    required this.level,
    required this.unit,
  });

  /// For a provider that only reports raw used/allowed and leaves percent
  /// and level for us to derive (Webdock computes both itself; Prometheus
  /// node_exporter and Docker stats don't). A null, zero, or NaN `allowed`
  /// (an unbounded resource, or one the provider can't report a ceiling
  /// for) yields a gauge with no percent and an `ok` level rather than a
  /// divide-by-zero or a NaN percent leaking into the UI. `warnAt`/`critAt`
  /// default to a generic 80/95; callers pass per-kind overrides (disk
  /// 70/90, container memory 85/95).
  factory Gauge.fromUsedAllowed(
    double used,
    double? allowed, {
    required String unit,
    double warnAt = 80,
    double critAt = 95,
  }) {
    if (allowed == null || allowed == 0 || allowed.isNaN || used.isNaN) {
      return Gauge(
        used: used,
        allowed: allowed,
        percentUsed: null,
        level: UsageLevel.ok,
        unit: unit,
      );
    }
    final percent = used / allowed * 100;
    final level = percent >= critAt
        ? UsageLevel.crit
        : percent >= warnAt
        ? UsageLevel.warn
        : UsageLevel.ok;
    return Gauge(
      used: used,
      allowed: allowed,
      percentUsed: percent,
      level: level,
      unit: unit,
    );
  }
}

class HostVitals {
  final String slug;
  final String name;
  final String status;
  final String ipv4;
  final Gauge cpu;
  final Gauge? memory;
  final Gauge? disk;
  final Gauge? network;
  final int? processCount;
  final DateTime sampledAt;
  final Map<String, String>? extra;

  const HostVitals({
    required this.slug,
    required this.name,
    required this.status,
    required this.ipv4,
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
    required this.processCount,
    required this.sampledAt,
    this.extra,
  });
}
