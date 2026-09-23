enum UsageLevel { ok, warn, crit }

class Gauge {
  final double used;
  final double allowed;
  final double percentUsed;
  final UsageLevel level;
  final String unit;

  const Gauge({
    required this.used,
    required this.allowed,
    required this.percentUsed,
    required this.level,
    required this.unit,
  });
}

class HostVitals {
  final String slug;
  final String name;
  final String status;
  final String ipv4;
  final Gauge cpu;
  final Gauge memory;
  final Gauge disk;
  final Gauge network;
  final int? processCount;
  final DateTime sampledAt;

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
  });
}
