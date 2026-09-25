/// One entry from `GET /containers/json?all=1`.
class DockerContainerSummaryDTO {
  final String id;
  final String name;
  final String image;
  final String state;

  const DockerContainerSummaryDTO({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
  });

  factory DockerContainerSummaryDTO.fromJson(Map<String, dynamic> json) {
    final names = (json['Names'] as List?)?.cast<String>() ?? const [];
    // Docker's own Names entries carry a leading '/' (e.g. "/my-container").
    final name = names.isEmpty
        ? (json['Id'] as String)
        : names.first.replaceFirst('/', '');
    return DockerContainerSummaryDTO(
      id: json['Id'] as String,
      name: name,
      image: json['Image'] as String? ?? '',
      state: json['State'] as String? ?? '',
    );
  }
}

/// `GET /containers/{id}/json`. Only the fields this app displays; a real
/// inspect response is much larger.
class DockerContainerInspectDTO {
  final int restartCount;
  final DateTime? startedAt;
  final String? healthStatus;

  const DockerContainerInspectDTO({
    required this.restartCount,
    required this.startedAt,
    required this.healthStatus,
  });

  factory DockerContainerInspectDTO.fromJson(Map<String, dynamic> json) {
    final state = json['State'] as Map<String, dynamic>? ?? const {};
    return DockerContainerInspectDTO(
      restartCount: (json['RestartCount'] as num?)?.toInt() ?? 0,
      startedAt: _parseStartedAt(state['StartedAt'] as String?),
      healthStatus:
          (state['Health'] as Map<String, dynamic>?)?['Status'] as String?,
    );
  }

  // A container that has never started reports the Go zero-time sentinel
  // ("0001-01-01T00:00:00Z"), not an absent field: parsing it literally
  // would produce a "started" timestamp thousands of years in the past.
  static DateTime? _parseStartedAt(String? raw) {
    if (raw == null || raw.startsWith('0001-01-01')) return null;
    return DateTime.tryParse(raw);
  }
}

/// `GET /containers/{id}/stats?stream=false`. CPU%/mem are computed here,
/// not left to the caller, since both need several raw fields at once and
/// every caller would otherwise repeat the same null-handling.
class DockerStatsDTO {
  final double? cpuPercent;
  final int? memUsed;
  final int? memLimit;

  const DockerStatsDTO({
    required this.cpuPercent,
    required this.memUsed,
    required this.memLimit,
  });

  factory DockerStatsDTO.fromJson(Map<String, dynamic> json) {
    final cpuStats = json['cpu_stats'] as Map<String, dynamic>? ?? const {};
    final precpuStats =
        json['precpu_stats'] as Map<String, dynamic>? ?? const {};
    final cpuUsage =
        (cpuStats['cpu_usage'] as Map<String, dynamic>?)?['total_usage']
            as num?;
    final precpuUsage =
        (precpuStats['cpu_usage'] as Map<String, dynamic>?)?['total_usage']
            as num?;
    final systemUsage = cpuStats['system_cpu_usage'] as num?;
    final presystemUsage = precpuStats['system_cpu_usage'] as num?;
    final onlineCpus = (cpuStats['online_cpus'] as num?)?.toInt();

    double? cpuPercent;
    // precpuUsage == 0 is a known Podman quirk (not "no CPU activity"): the
    // daemon can return a zeroed precpu_stats snapshot, which would make
    // the delta below equal the *entire* lifetime usage, not one interval.
    if (cpuUsage != null &&
        precpuUsage != null &&
        precpuUsage != 0 &&
        systemUsage != null &&
        presystemUsage != null &&
        onlineCpus != null) {
      final systemDelta = systemUsage - presystemUsage;
      if (systemDelta > 0) {
        final cpuDelta = cpuUsage - precpuUsage;
        cpuPercent = (cpuDelta / systemDelta) * onlineCpus * 100;
      }
    }

    final memoryStats =
        json['memory_stats'] as Map<String, dynamic>? ?? const {};
    final usage = (memoryStats['usage'] as num?)?.toInt();
    final memStats = memoryStats['stats'] as Map<String, dynamic>?;
    final inactiveFile = (memStats?['inactive_file'] as num?)?.toInt();
    final cache = (memStats?['cache'] as num?)?.toInt();
    final memUsed = usage == null ? null : usage - (inactiveFile ?? cache ?? 0);

    return DockerStatsDTO(
      cpuPercent: cpuPercent,
      memUsed: memUsed,
      memLimit: (memoryStats['limit'] as num?)?.toInt(),
    );
  }
}
