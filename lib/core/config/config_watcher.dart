import '../platform/config_store.dart';

class ConfigWatcher {
  final String dir;
  late final ConfigStore _store = createConfigStoreForDir(dir);

  ConfigWatcher(this.dir);

  Stream<void> get events => _store.changes();
}
