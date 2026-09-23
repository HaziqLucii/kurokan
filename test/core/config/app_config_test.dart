import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';

Map<String, dynamic> _fullJson() => {
      'webdock': {'slug': 'webdock-prod-01', 'apiToken': 'wd_secret'},
      'kuma': {'url': 'https://status.example.tld', 'apiKey': 'uk1_secret'},
      'pollIntervalSec': 45,
      'theme': 'dark',
    };

void main() {
  group('AppConfig.fromJson', () {
    test('round-trips through toJson', () {
      final config = AppConfig.fromJson(_fullJson());
      final roundTripped = AppConfig.fromJson(config.toJson());

      expect(roundTripped.webdock.slug, config.webdock.slug);
      expect(roundTripped.webdock.apiToken, config.webdock.apiToken);
      expect(roundTripped.kuma.url, config.kuma.url);
      expect(roundTripped.kuma.apiKey, config.kuma.apiKey);
      expect(roundTripped.pollInterval, config.pollInterval);
      expect(roundTripped.theme, config.theme);
    });

    test('defaults pollIntervalSec to 30 and theme to system when omitted', () {
      final json = _fullJson()
        ..remove('pollIntervalSec')
        ..remove('theme');
      final config = AppConfig.fromJson(json);

      expect(config.pollInterval, const Duration(seconds: 30));
      expect(config.theme, ThemePreference.system);
    });

    test('parses each theme value', () {
      for (final entry in {
        'system': ThemePreference.system,
        'dark': ThemePreference.dark,
        'light': ThemePreference.light,
      }.entries) {
        final json = _fullJson()..['theme'] = entry.key;
        expect(AppConfig.fromJson(json).theme, entry.value);
      }
    });

    test('throws FormatException for an unknown theme value', () {
      final json = _fullJson()..['theme'] = 'sepia';
      expect(() => AppConfig.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when theme is not a string', () {
      final json = _fullJson()..['theme'] = 1;
      expect(() => AppConfig.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when pollIntervalSec is zero or negative', () {
      for (final value in [0, -5]) {
        final json = _fullJson()..['pollIntervalSec'] = value;
        expect(() => AppConfig.fromJson(json), throwsFormatException);
      }
    });

    test('throws FormatException when webdock section is missing', () {
      final json = _fullJson()..remove('webdock');
      expect(() => AppConfig.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when kuma.apiKey is missing', () {
      final json = _fullJson();
      (json['kuma'] as Map<String, dynamic>).remove('apiKey');
      expect(() => AppConfig.fromJson(json), throwsFormatException);
    });
  });
}
