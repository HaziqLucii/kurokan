import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _dartIoImport = RegExp(r'''^import\s+['"]dart:io['"]''', multiLine: true);
final _allowedNetIoShim = RegExp(r'/core/net/[^/]+_io\.dart$');
final _allowedDataDir = RegExp(r'/features/[^/]+/data/');

void main() {
  test('dart:io stays behind lib/core/platform/**, lib/core/net/*_io.dart, '
      'and lib/features/**/data/**', () {
    final offenders = <String>[];

    for (final entity in Directory(
      'lib',
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');

      if (path.contains('/core/platform/')) continue;
      if (_allowedNetIoShim.hasMatch(path)) continue;
      if (_allowedDataDir.hasMatch(path)) continue;

      if (_dartIoImport.hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(offenders, isEmpty, reason: 'unexpected dart:io in: $offenders');
  });
}
