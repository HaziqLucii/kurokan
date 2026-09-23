import 'host_vitals.dart';

abstract interface class VitalsSource {
  Future<HostVitals> fetch();
}
