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

  test(
    'changes() ignores writes to unrelated files in the same directory',
    () async {
      final store = createConfigStoreForDir(tempDir.path);
      final events = <void>[];
      final sub = store.changes().listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      // A stray file (editor swap file, .DS_Store, an unrelated JSONL) must
      // not trigger a reload: only config.json and config.json.tmp should.
      File('${tempDir.path}/.DS_Store').writeAsStringSync('junk');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(events, isEmpty);

      File('${tempDir.path}/config.json.tmp').writeAsStringSync('{}');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(events.length, 1);

      await sub.cancel();
    },
  );

  test('changes() fires when an arbitrarily-named temp file is renamed onto '
      'the config file (an external atomic write, not our own .tmp)', () async {
    final store = createConfigStoreForDir(tempDir.path);
    final events = <void>[];
    final sub = store.changes().listen(events.add);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    // e.g. `jq ... > .config.json.swp && mv .config.json.swp config.json`,
    // or a JetBrains/vim "safe write": on Linux this reports as a single
    // FileSystemMoveEvent whose `path` is the temp name, not config.json.
    final tempFile = File('${tempDir.path}/.config.json.swp123')
      ..writeAsStringSync('{}');
    tempFile.renameSync('${tempDir.path}/config.json');

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
