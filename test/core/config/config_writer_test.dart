import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_writer.dart';

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
    const config = AppConfig(
      webdock: WebdockConfig(slug: 'demo', apiToken: 'wd_secret'),
      kuma: KumaConfig(url: 'https://kuma.test', apiKey: 'uk1_secret'),
      pollInterval: Duration(seconds: 45),
      theme: ThemePreference.dark,
    );

    ConfigWriter(path).write(config);

    final file = File(path);
    expect(file.existsSync(), isTrue);

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final roundTripped = AppConfig.fromJson(decoded);
    expect(roundTripped.webdock.slug, 'demo');
    expect(roundTripped.webdock.apiToken, 'wd_secret');
    expect(roundTripped.kuma.url, 'https://kuma.test');
    expect(roundTripped.kuma.apiKey, 'uk1_secret');
    expect(roundTripped.pollInterval, const Duration(seconds: 45));
    expect(roundTripped.theme, ThemePreference.dark);
  });

  test('creates missing parent directories', () {
    final path = '${tempDir.path}/a/b/c/config.json';
    const config = AppConfig(
      webdock: WebdockConfig(slug: 'demo', apiToken: 'wd_secret'),
      kuma: KumaConfig(url: 'https://kuma.test', apiKey: 'uk1_secret'),
    );

    ConfigWriter(path).write(config);

    expect(File(path).existsSync(), isTrue);
  });

  test('sets file permissions to 0600', () {
    final path = '${tempDir.path}/config.json';
    const config = AppConfig(
      webdock: WebdockConfig(slug: 'demo', apiToken: 'wd_secret'),
      kuma: KumaConfig(url: 'https://kuma.test', apiKey: 'uk1_secret'),
    );

    ConfigWriter(path).write(config);

    final mode = File(path).statSync().modeString();
    // rw------- : owner read/write only, nothing for group/other.
    expect(mode, 'rw-------');
  });
}
