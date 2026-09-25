import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';

import 'helpers/test_config.dart';

void main() {
  final exampleJson =
      jsonDecode(File('config.example.json').readAsStringSync())
          as Map<String, dynamic>;
  final schemaJson =
      jsonDecode(File('docs/config.schema.json').readAsStringSync())
          as Map<String, dynamic>;

  test('config.example.json parses through AppConfig.fromJson', () {
    final config = AppConfig.fromJson(exampleJson, schema: testConfigSchema);

    expect(config.firstHost?.settings['slug'], 'webdock-prod-01');
    expect(config.firstUptime?.settings['url'], 'https://status.example.tld');
    expect(config.containers.single.settings['endpoint'], 'auto');
    expect(config.pollInterval, const Duration(seconds: 30));
    expect(config.theme, ThemePreference.system);
  });

  test('docs/config.schema.json properties match AppConfig.toJson() keys', () {
    final config = AppConfig.fromJson(exampleJson, schema: testConfigSchema);
    final schemaKeys = (schemaJson['properties'] as Map<String, dynamic>).keys
        .where((key) => key != r'$schema')
        .toSet();

    expect(schemaKeys, config.toJson().keys.toSet());
  });

  test('config.example.json declares the published schema URL', () {
    expect(
      exampleJson[r'$schema'],
      'https://raw.githubusercontent.com/HaziqLucii/kurokan/main/docs/config.schema.json',
    );
  });
}
