import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_writer.dart';

import '../../helpers/test_config.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('config_writer_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('writes a config that round-trips through AppConfig.fromJson', () {
    final path = '${tempDir.path}/nested/config.json';
    final config = testConfig(
      webdockSlug: 'demo',
      webdockToken: 'wd_secret',
      kumaUrl: 'https://kuma.test',
      kumaApiKey: 'uk1_secret',
      pollInterval: const Duration(seconds: 45),
      theme: ThemePreference.dark,
    );

    ConfigWriter(path).write(config);

    final file = File(path);
    expect(file.existsSync(), isTrue);

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['version'], 2);

    final roundTripped = AppConfig.fromJson(decoded, schema: testConfigSchema);
    expect(roundTripped.firstHost?.settings['slug'], 'demo');
    expect(roundTripped.firstHost?.settings['apiToken'], 'wd_secret');
    expect(roundTripped.firstUptime?.settings['url'], 'https://kuma.test');
    expect(roundTripped.firstUptime?.settings['apiKey'], 'uk1_secret');
    expect(roundTripped.pollInterval, const Duration(seconds: 45));
    expect(roundTripped.theme, ThemePreference.dark);
  });

  test('creates missing parent directories', () {
    final path = '${tempDir.path}/a/b/c/config.json';
    ConfigWriter(path).write(testConfig());

    expect(File(path).existsSync(), isTrue);
  });

  test('sets file permissions to 0600', () {
    final path = '${tempDir.path}/config.json';
    ConfigWriter(path).write(testConfig());

    final mode = File(path).statSync().modeString();
    // rw------- : owner read/write only, nothing for group/other.
    expect(mode, 'rw-------');
  });
}
