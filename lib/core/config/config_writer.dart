import 'dart:convert';

import '../platform/config_store.dart';
import 'app_config.dart';

class ConfigWriter {
  final String path;
  late final ConfigStore _store = createConfigStoreForPath(path);

  ConfigWriter(this.path);

  void write(AppConfig config) {
    final jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(config.toJson());
    _store.writePrivate(jsonText);
  }
}
