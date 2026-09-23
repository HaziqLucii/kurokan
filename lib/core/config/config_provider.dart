import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden with a loaded AppConfig');
});

final configPathProvider = Provider<String>((ref) {
  throw UnimplementedError('configPathProvider must be overridden with the loaded config file path');
});
