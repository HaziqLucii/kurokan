import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// Imports the memory implementation directly: `flutter test` runs on the
// Dart VM, where dart.library.io is always true, so importing config_store.dart
// here would resolve to the io-backed store instead of the one under test.
import 'package:kurokan/core/platform/config_store_memory.dart';

void main() {
  group('memory ConfigStore', () {
    test('round-trips a write through read/exists', () {
      final store = createConfigStoreForPath('/mem/round-trip/config.json');

      expect(store.exists(), isFalse);

      store.writePrivate('{"hello":"world"}');

      expect(store.exists(), isTrue);
      expect(store.read(), '{"hello":"world"}');
      expect(store.dir, '/mem/round-trip');
    });

    test('changes() emits after a write to the same path', () async {
      final store = createConfigStoreForPath('/mem/changes/config.json');
      final completer = Completer<void>();
      final sub = store.changes().listen((_) => completer.complete());

      store.writePrivate('{}');

      await completer.future.timeout(const Duration(seconds: 1));
      await sub.cancel();
    });

    test('createConfigStore resolves KUROKAN_CONFIG override', () {
      final store = createConfigStore(
        env: {'KUROKAN_CONFIG': '/mem/override/custom.json'},
        home: '/unused',
      );
      expect(store.path, '/mem/override/custom.json');
    });

    test('createConfigStore falls back to home when unset', () {
      final store = createConfigStore(env: const {}, home: '/mem/home');
      expect(store.path, '/mem/home/.config/kurokan/config.json');
    });
  });
}
