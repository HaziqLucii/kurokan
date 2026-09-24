import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';

import '../../helpers/test_config.dart';

Map<String, dynamic> _fullJson() =>
    testConfigJson(pollIntervalSec: 45, theme: 'dark');

void main() {
  group('AppConfig.fromJson', () {
    test('round-trips through toJson', () {
      final config = AppConfig.fromJson(_fullJson(), schema: testConfigSchema);
      final roundTripped = AppConfig.fromJson(
        config.toJson(),
        schema: testConfigSchema,
      );

      expect(
        roundTripped.firstHost?.settings['slug'],
        config.firstHost?.settings['slug'],
      );
      expect(
        roundTripped.firstHost?.settings['apiToken'],
        config.firstHost?.settings['apiToken'],
      );
      expect(
        roundTripped.firstUptime?.settings['url'],
        config.firstUptime?.settings['url'],
      );
      expect(
        roundTripped.firstUptime?.settings['apiKey'],
        config.firstUptime?.settings['apiKey'],
      );
      expect(roundTripped.pollInterval, config.pollInterval);
      expect(roundTripped.theme, config.theme);
    });

    test('emits version: 2', () {
      final config = AppConfig.fromJson(_fullJson(), schema: testConfigSchema);
      expect(config.toJson()['version'], 2);
    });

    test('defaults pollIntervalSec to 30 and theme to system when omitted', () {
      final config = AppConfig.fromJson(
        testConfigJson(),
        schema: testConfigSchema,
      );

      expect(config.pollInterval, const Duration(seconds: 30));
      expect(config.theme, ThemePreference.system);
    });

    test('parses each theme value', () {
      for (final entry in {
        'system': ThemePreference.system,
        'dark': ThemePreference.dark,
        'light': ThemePreference.light,
      }.entries) {
        final json = testConfigJson(theme: entry.key);
        expect(
          AppConfig.fromJson(json, schema: testConfigSchema).theme,
          entry.value,
        );
      }
    });

    test('throws FormatException for an unknown theme value', () {
      final json = testConfigJson(theme: 'sepia');
      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsFormatException,
      );
    });

    test('throws FormatException when theme is not a string', () {
      final json = _fullJson()..['theme'] = 1;
      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsFormatException,
      );
    });

    test('throws FormatException when pollIntervalSec is zero or negative', () {
      for (final value in [0, -5]) {
        final json = _fullJson()..['pollIntervalSec'] = value;
        expect(
          () => AppConfig.fromJson(json, schema: testConfigSchema),
          throwsFormatException,
        );
      }
    });

    test('throws FormatException when there are no sources at all', () {
      final json = _fullJson()
        ..['hosts'] = <Map<String, dynamic>>[]
        ..['uptime'] = <Map<String, dynamic>>[];
      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('at least one source'),
          ),
        ),
      );
    });

    test('does not throw when only one of hosts/uptime has an entry', () {
      final hostsOnly = _fullJson()..['uptime'] = <Map<String, dynamic>>[];
      expect(
        () => AppConfig.fromJson(hostsOnly, schema: testConfigSchema),
        returnsNormally,
      );
    });

    test(
      'throws FormatException naming the field when uptime.apiKey is missing',
      () {
        final json = _fullJson();
        (json['uptime'] as List).cast<Map<String, dynamic>>().first.remove(
          'apiKey',
        );
        expect(
          () => AppConfig.fromJson(json, schema: testConfigSchema),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('uptime[0].apiKey is required'),
            ),
          ),
        );
      },
    );

    test(
      'throws FormatException naming the unknown provider and the allowed ids',
      () {
        final json = _fullJson();
        (json['hosts'] as List).cast<Map<String, dynamic>>().first['provider'] =
            'nonexistent';
        expect(
          () => AppConfig.fromJson(json, schema: testConfigSchema),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('unknown provider "nonexistent"'),
                contains('known: webdock'),
              ),
            ),
          ),
        );
      },
    );

    test(
      'throws FormatException naming an empty allowed list for containers',
      () {
        final json = _fullJson()
          ..['containers'] = [
            {'id': 'docker', 'provider': 'docker', 'endpoint': 'unix:///x'},
          ];
        expect(
          () => AppConfig.fromJson(json, schema: testConfigSchema),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('none configured for this build'),
            ),
          ),
        );
      },
    );

    test('throws FormatException for an unsupported config version', () {
      final json = _fullJson()..['version'] = 3;
      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('unsupported config version'),
          ),
        ),
      );
    });

    test('throws FormatException when ids collide across lists', () {
      final json = _fullJson();
      final hosts = (json['hosts'] as List).cast<Map<String, dynamic>>();
      final uptime = (json['uptime'] as List).cast<Map<String, dynamic>>();
      uptime.first['id'] = hosts.first['id'];

      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('duplicate source id'),
          ),
        ),
      );
    });

    test('throws FormatException when a list is not a list', () {
      final json = _fullJson()..['hosts'] = 'not-a-list';
      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'hosts must be a list',
          ),
        ),
      );
    });

    test('throws FormatException when a list entry is not an object', () {
      final json = _fullJson()..['hosts'] = ['not-an-object'];
      expect(
        () => AppConfig.fromJson(json, schema: testConfigSchema),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'hosts[0] must be an object',
          ),
        ),
      );
    });
  });

  group('ConfigError', () {
    test('toString includes the path and reason', () {
      const error = ConfigError('/x/config.json', 'not found');
      expect(error.toString(), 'ConfigError(/x/config.json: not found)');
    });
  });
}
