import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

class ConfigWriter {
  final String path;
  const ConfigWriter(this.path);

  void write(AppConfig config) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    final jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(config.toJson());

    final tempFile = File('$path.tmp');
    tempFile.writeAsStringSync(jsonText);
    final chmodResult = Process.runSync('chmod', ['600', tempFile.path]);
    if (chmodResult.exitCode != 0) {
      tempFile.deleteSync();
      throw StateError('chmod failed: ${chmodResult.stderr}');
    }
    tempFile.renameSync(file.path);
  }
}
