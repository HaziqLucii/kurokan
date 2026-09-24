import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_loader.dart';

import '../../helpers/test_config.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('infra_monitor_config_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
    'KUROKAN_CONFIG overrides the default path and loads a v1 file, migrated',
    () {
      final file = File('${tempDir.path}/config.json');
      file.writeAsStringSync(
        jsonEncode({
          'webdock': {'slug': 'webdock-prod-01', 'apiToken': 'wd_secret'},
          'kuma': {'url': 'https://status.example.tld', 'apiKey': 'uk1_secret'},
        }),
      );

      final loader = ConfigLoader(
        env: {'KUROKAN_CONFIG': file.path},
        home: '/unused',
        schema: testConfigSchema,
      );
      final config = loader.load();

      expect(loader.filePath, file.path);
      expect(config.firstHost?.settings['slug'], 'webdock-prod-01');
      expect(config.firstUptime?.settings['apiKey'], 'uk1_secret');
      expect(config.pollInterval, const Duration(seconds: 30));
    },
  );

  test('loads a v2 file with hosts/uptime lists directly, no migration', () {
    final file = File('${tempDir.path}/config.json');
    file.writeAsStringSync(jsonEncode(testConfigJson(webdockSlug: 'v2-host')));

    final loader = ConfigLoader(
      env: {'KUROKAN_CONFIG': file.path},
      home: '/unused',
      schema: testConfigSchema,
    );
    final config = loader.load();

    expect(config.firstHost?.settings['slug'], 'v2-host');
  });

  test(
    'falls back to ~/.config/kurokan/config.json when no override is set',
    () {
      final loader = ConfigLoader(
        env: const {},
        home: '/home/haziq',
        schema: testConfigSchema,
      );
      expect(loader.filePath, '/home/haziq/.config/kurokan/config.json');
      expect(loader.dir, '/home/haziq/.config/kurokan');
    },
  );

  test('dir does not crash for a slash-less relative override path', () {
    final loader = ConfigLoader(
      env: {'KUROKAN_CONFIG': 'config.json'},
      home: '/unused',
      schema: testConfigSchema,
    );
    expect(loader.dir, '.');
  });

  test('throws ConfigError naming the path when the file does not exist', () {
    final missingPath = '${tempDir.path}/missing.json';
    final loader = ConfigLoader(
      env: {'KUROKAN_CONFIG': missingPath},
      home: '/unused',
      schema: testConfigSchema,
    );

    expect(
      loader.load,
      throwsA(
        isA<ConfigError>()
            .having((e) => e.path, 'path', missingPath)
            .having((e) => e.reason, 'reason', 'not found')
            .having((e) => e.notFound, 'notFound', isTrue),
      ),
    );
  });

  test(
    'throws ConfigError with the reason when the file has malformed JSON',
    () {
      final file = File('${tempDir.path}/config.json');
      file.writeAsStringSync('{not valid json');

      final loader = ConfigLoader(
        env: {'KUROKAN_CONFIG': file.path},
        home: '/unused',
        schema: testConfigSchema,
      );

      expect(
        loader.load,
        throwsA(
          isA<ConfigError>()
              .having((e) => e.path, 'path', file.path)
              .having((e) => e.reason, 'reason', contains('invalid JSON'))
              .having((e) => e.notFound, 'notFound', isFalse),
        ),
      );
    },
  );

  test('ensureDir creates the parent directory', () {
    final override = '${tempDir.path}/nested/deeper/config.json';
    final loader = ConfigLoader(
      env: {'KUROKAN_CONFIG': override},
      home: '/unused',
      schema: testConfigSchema,
    );

    loader.ensureDir();

    expect(Directory('${tempDir.path}/nested/deeper').existsSync(), isTrue);
  });

  test('throws ConfigError when the JSON root is not an object', () {
    final file = File('${tempDir.path}/config.json');
    file.writeAsStringSync(jsonEncode([1, 2, 3]));

    final loader = ConfigLoader(
      env: {'KUROKAN_CONFIG': file.path},
      home: '/unused',
      schema: testConfigSchema,
    );

    expect(
      loader.load,
      throwsA(
        isA<ConfigError>().having(
          (e) => e.reason,
          'reason',
          'root must be a JSON object',
        ),
      ),
    );
  });

  test(
    'throws ConfigError with the reason when a required field is missing',
    () {
      final file = File('${tempDir.path}/config.json');
      file.writeAsStringSync(
        jsonEncode({
          'webdock': {'slug': 'webdock-prod-01', 'apiToken': 'wd_secret'},
          'kuma': {'url': 'https://status.example.tld'},
        }),
      );

      final loader = ConfigLoader(
        env: {'KUROKAN_CONFIG': file.path},
        home: '/unused',
        schema: testConfigSchema,
      );

      expect(
        loader.load,
        throwsA(
          isA<ConfigError>().having(
            (e) => e.reason,
            'reason',
            contains('apiKey'),
          ),
        ),
      );
    },
  );
}
