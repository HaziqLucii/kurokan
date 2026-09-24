import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_migration.dart';

import '../../helpers/test_config.dart';

void main() {
  group('isV1Config', () {
    test('true for a file with webdock+kuma sections and no version', () {
      expect(
        isV1Config({
          'webdock': {'slug': 'x', 'apiToken': 'y'},
          'kuma': {'url': 'z', 'apiKey': 'w'},
        }),
        isTrue,
      );
    });

    test('false when version is present', () {
      expect(
        isV1Config({
          'version': 2,
          'webdock': {'slug': 'x'},
          'kuma': {'url': 'z'},
        }),
        isFalse,
      );
    });

    test('false when webdock or kuma is missing', () {
      expect(isV1Config({'webdock': {}}), isFalse);
      expect(isV1Config({'kuma': {}}), isFalse);
      expect(isV1Config({}), isFalse);
    });
  });

  group('migrateV1ToV2', () {
    test(
      'migrates a full v1 fixture to a v2 shape that AppConfig.fromJson accepts',
      () {
        final v1 = {
          'webdock': {'slug': 'webdock-prod-01', 'apiToken': 'wd_secret'},
          'kuma': {'url': 'https://status.example.tld', 'apiKey': 'uk1_secret'},
          'pollIntervalSec': 45,
          'theme': 'dark',
        };

        final v2 = migrateV1ToV2(v1);
        final config = AppConfig.fromJson(v2, schema: testConfigSchema);

        expect(v2['version'], 2);
        expect(config.firstHost?.id, 'webdock');
        expect(config.firstHost?.provider, 'webdock');
        expect(config.firstHost?.settings['slug'], 'webdock-prod-01');
        expect(config.firstUptime?.id, 'kuma');
        expect(config.firstUptime?.settings['apiKey'], 'uk1_secret');
        expect(config.pollInterval, const Duration(seconds: 45));
        expect(config.theme, ThemePreference.dark);
      },
    );

    test(
      'a v1 file missing webdock.slug still reads "hosts[0].slug is required"',
      () {
        final v1 = {
          'webdock': {'apiToken': 'wd_secret'},
          'kuma': {'url': 'https://status.example.tld', 'apiKey': 'uk1_secret'},
        };

        final v2 = migrateV1ToV2(v1);
        expect(
          () => AppConfig.fromJson(v2, schema: testConfigSchema),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'hosts[0].slug is required',
            ),
          ),
        );
      },
    );

    test(
      'omits pollIntervalSec/theme when absent from v1, keeping AppConfig defaults',
      () {
        final v1 = {
          'webdock': {'slug': 'x', 'apiToken': 'y'},
          'kuma': {'url': 'z', 'apiKey': 'w'},
        };
        final v2 = migrateV1ToV2(v1);
        final config = AppConfig.fromJson(v2, schema: testConfigSchema);

        expect(config.pollInterval, const Duration(seconds: 30));
        expect(config.theme, ThemePreference.system);
      },
    );

    test('always emits an empty containers list', () {
      final v2 = migrateV1ToV2({
        'webdock': {'slug': 'x', 'apiToken': 'y'},
        'kuma': {'url': 'z', 'apiKey': 'w'},
      });
      expect(v2['containers'], isEmpty);
    });
  });
}
