import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/features/vps/data/webdock_source.dart';
import 'package:kurokan/features/vps/presentation/vitals_provider.dart';

import '../../../helpers/test_config.dart';

void main() {
  test('builds a WebdockSource from the first configured host', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          testConfig(webdockSlug: 'my-vps', webdockToken: 'wd_secret'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final source = container.read(vitalsSourceProvider);

    expect(source, isA<WebdockSource>());
    expect((source as WebdockSource).slug, 'my-vps');
    expect(source.apiToken, 'wd_secret');
  });

  test('throws when no host is configured', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            uptime: [
              SourceEntry(
                kind: SourceKind.uptime,
                id: 'kuma',
                provider: 'kuma',
                settings: {'url': 'https://kuma.test', 'apiKey': 'k'},
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // config.firstHost! null-check fails, surfaced by Riverpod wrapped in
    // its own internal exception type: a documented Phase 1.1 scope trim
    // (see docs/DECISIONS.md), not yet a clean error state.
    expect(() => container.read(vitalsSourceProvider), throwsA(anything));
  });
}
