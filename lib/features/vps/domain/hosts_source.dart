import 'host_vitals.dart';

abstract interface class HostsSource {
  Future<List<HostVitals>> fetch();
}
