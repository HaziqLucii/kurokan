class ServerDTO {
  final String slug;
  final String name;
  final String status;
  final String? ipv4;

  const ServerDTO({required this.slug, required this.name, required this.status, this.ipv4});

  factory ServerDTO.fromJson(Map<String, dynamic> json) => ServerDTO(
        slug: json['slug'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        ipv4: json['ipv4'] as String?,
      );
}

class ResourceUsageMetricStatusDTO {
  final double used;
  final double allowed;
  final double percentUsed;
  final String level;

  const ResourceUsageMetricStatusDTO({
    required this.used,
    required this.allowed,
    required this.percentUsed,
    required this.level,
  });

  factory ResourceUsageMetricStatusDTO.fromJson(Map<String, dynamic> json) => ResourceUsageMetricStatusDTO(
        used: (json['used'] as num).toDouble(),
        allowed: (json['allowed'] as num).toDouble(),
        percentUsed: (json['percentUsed'] as num).toDouble(),
        level: json['level'] as String,
      );
}

class ResourceUsageStatusDTO {
  final ResourceUsageMetricStatusDTO cpu;
  final ResourceUsageMetricStatusDTO memory;
  final ResourceUsageMetricStatusDTO disk;
  final ResourceUsageMetricStatusDTO network;

  const ResourceUsageStatusDTO({
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
  });

  factory ResourceUsageStatusDTO.fromJson(Map<String, dynamic> json) => ResourceUsageStatusDTO(
        cpu: ResourceUsageMetricStatusDTO.fromJson(json['cpu'] as Map<String, dynamic>),
        memory: ResourceUsageMetricStatusDTO.fromJson(json['memory'] as Map<String, dynamic>),
        disk: ResourceUsageMetricStatusDTO.fromJson(json['disk'] as Map<String, dynamic>),
        network: ResourceUsageMetricStatusDTO.fromJson(json['network'] as Map<String, dynamic>),
      );
}

class InstantServerMetricsDTO {
  final ResourceUsageStatusDTO resourceUsageStatus;
  final DateTime memorySampledAt;
  final int? processCount;

  const InstantServerMetricsDTO({
    required this.resourceUsageStatus,
    required this.memorySampledAt,
    required this.processCount,
  });

  factory InstantServerMetricsDTO.fromJson(Map<String, dynamic> json) {
    final memory = json['memory'] as Map<String, dynamic>?;
    final memSampling = memory?['latestUsageSampling'] as Map<String, dynamic>?;
    final processes = json['processes'] as Map<String, dynamic>?;
    final procSampling = processes?['latestProcessesSampling'] as Map<String, dynamic>?;

    return InstantServerMetricsDTO(
      resourceUsageStatus: ResourceUsageStatusDTO.fromJson(json['resourceUsageStatus'] as Map<String, dynamic>),
      // No field in this schema is marked required, so treat a missing
      // sample timestamp as a parse failure rather than defaulting to "now".
      memorySampledAt: DateTime.parse(memSampling?['timestamp'] as String).toLocal(),
      processCount: (procSampling?['amount'] as num?)?.round(),
    );
  }
}
