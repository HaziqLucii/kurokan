enum ContainerState {
  running,
  exited,
  paused,
  restarting,
  created,
  dead,
  unknown,
}

enum HealthState { healthy, unhealthy, starting, none }

class ContainerStatus {
  final String id;
  final String name;
  final String image;
  final ContainerState state;
  final HealthState health;
  final int restartCount;
  final double? cpuPercent;
  final int? memUsed;
  final int? memLimit;
  final DateTime? startedAt;

  const ContainerStatus({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.health,
    required this.restartCount,
    required this.cpuPercent,
    required this.memUsed,
    required this.memLimit,
    required this.startedAt,
  });
}

abstract interface class ContainerSource {
  Future<List<ContainerStatus>> fetch();
}
