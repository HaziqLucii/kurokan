import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/features/uptime/data/uptime_kuma_metrics_source.dart';
import 'package:kurokan/features/uptime/presentation/monitors_provider.dart';

import '../../../helpers/test_config.dart';

void main() {
  test(
    'builds an UptimeKumaMetricsSource from the first configured uptime source',
    () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            testConfig(
              kumaUrl: 'https://kuma.example.tld',
              kumaApiKey: 'uk1_secret',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final source = container.read(monitorSourceProvider);

      expect(source, isA<UptimeKumaMetricsSource>());
      expect(
        (source as UptimeKumaMetricsSource).baseUrl,
        Uri.parse('https://kuma.example.tld'),
      );
      expect(source.apiKey, 'uk1_secret');
    },
  );

  test('throws when no uptime source is configured', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            hosts: [
              SourceEntry(
                kind: SourceKind.host,
                id: 'webdock',
                provider: 'webdock',
                settings: {'slug': 's', 'apiToken': 't'},
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // config.firstUptime! null-check fails, surfaced by Riverpod wrapped in
    // its own internal exception type: a documented Phase 1.1 scope trim
    // (see docs/DECISIONS.md), not yet a clean error state.
    expect(() => container.read(monitorSourceProvider), throwsA(anything));
  });
}
