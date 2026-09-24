import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/platform/config_store_io.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('config_store_io_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('createConfigStoreForDir watches the directory and debounces', () async {
    final store = createConfigStoreForDir(tempDir.path);
    final events = <void>[];
    final sub = store.changes().listen(events.add);

    // Give Directory.watch() a moment to attach before writing.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    File('${tempDir.path}/config.json').writeAsStringSync('{}');

    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(events.length, 1);

    await sub.cancel();
  });

  test('createConfigStore resolves KUROKAN_CONFIG override and falls back', () {
    final overridden = createConfigStore(
      env: {'KUROKAN_CONFIG': '${tempDir.path}/custom.json'},
      home: '/unused',
    );
    expect(overridden.path, '${tempDir.path}/custom.json');

    final fallback = createConfigStore(env: const {}, home: tempDir.path);
    expect(fallback.path, '${tempDir.path}/.config/kurokan/config.json');
  });
}
