import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/features/uptime/data/uptime_kuma_metrics_source.dart';
import 'package:kurokan/features/uptime/presentation/uptime_provider.dart';

import '../../../helpers/test_config.dart';

void main() {
  test(
    'builds an UptimeKumaMetricsSource for the matching uptime entry id',
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

      // 'kuma' is the fixed id testConfig() gives its uptime entry.
      final source = container.read(uptimeSourceProvider('kuma'));

      expect(source, isA<UptimeKumaMetricsSource>());
      expect(
        (source as UptimeKumaMetricsSource).baseUrl,
        Uri.parse('https://kuma.example.tld'),
      );
      expect(source.apiKey, 'uk1_secret');
    },
  );

  test('throws when the requested source id has no matching uptime entry', () {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(testConfig())],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(uptimeSourceProvider('nonexistent')),
      throwsA(anything),
    );
  });
}
