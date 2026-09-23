enum MonitorState { up, down, pending, maintenance }

class MonitorStatus {
  final String id;
  final String name;
  final String type;
  final MonitorState state;
  final Duration? responseTime;
  final double? uptime24h;
  final int? certDaysRemaining;
  final bool? certValid;

  const MonitorStatus({
    required this.id,
    required this.name,
    required this.type,
    required this.state,
    this.responseTime,
    this.uptime24h,
    this.certDaysRemaining,
    this.certValid,
  });
}
