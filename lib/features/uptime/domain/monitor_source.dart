import 'monitor_status.dart';

abstract interface class MonitorSource {
  Future<List<MonitorStatus>> fetch();
}
