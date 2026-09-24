import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_migration.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/core/net/http_client.dart';
import 'package:kurokan/core/providers/default_registry.dart';
import 'package:kurokan/features/dashboard/panel_registry.dart';

ProviderContainer _containerFor(AppConfig config) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      // Never hit the real network: the panel registry watches the polled
      // families, which construct a real WebdockSource/UptimeKumaMetricsSource
      // and would otherwise fire an actual HTTP request on the first read.
      httpClientProvider.overrideWithValue(
        MockClient((_) async => http.Response('', 500)),
      ),
    ],
  );
}

void main() {
  test(
    'a migrated v1 config yields exactly [uptime:kuma wide, host:webdock narrow]',
    () {
      final v1 = {
        'webdock': {'slug': 'webdock-prod-01', 'apiToken': 'wd_secret'},
        'kuma': {'url': 'https://status.example.tld', 'apiKey': 'uk1_secret'},
      };
      final config = AppConfig.fromJson(
        migrateV1ToV2(v1),
        schema: defaultRegistry,
      );

      final container = _containerFor(config);
      addTearDown(container.dispose);

      final panels = container.read(panelRegistryProvider);

      expect(panels.map((p) => p.key).toList(), [
        'uptime:kuma',
        'host:webdock',
      ]);
      expect(panels.map((p) => p.slot).toList(), [
        PanelSlot.wide,
        PanelSlot.narrow,
      ]);
    },
  );

  test('layout.order reorders panels; unlisted keys sort to the end', () {
    const config = AppConfig(
      hosts: [
        SourceEntry(
          kind: SourceKind.host,
          id: 'first',
          provider: 'webdock',
          settings: {'slug': 'a', 'apiToken': 'b'},
        ),
        SourceEntry(
          kind: SourceKind.host,
          id: 'second',
          provider: 'webdock',
          settings: {'slug': 'c', 'apiToken': 'd'},
        ),
      ],
      uptime: [
        SourceEntry(
          kind: SourceKind.uptime,
          id: 'kuma',
          provider: 'kuma',
          settings: {'url': 'https://kuma.test', 'apiKey': 'k'},
        ),
      ],
      layout: LayoutConfig(order: ['host:second']),
    );

    final container = _containerFor(config);
    addTearDown(container.dispose);

    final panels = container.read(panelRegistryProvider);

    // 'host:second' is named in layout.order, so it comes first; everything
    // else (not listed) keeps its original relative order after it.
    expect(panels.map((p) => p.key).toList(), [
      'host:second',
      'uptime:kuma',
      'host:first',
    ]);
  });

  group('marginMetaProvider', () {
    test(
      'uses the single host\'s own label when exactly one is configured',
      () {
        const config = AppConfig(
          hosts: [
            SourceEntry(
              kind: SourceKind.host,
              id: 'webdock',
              provider: 'webdock',
              settings: {'slug': 'my-vps', 'apiToken': 'x'},
            ),
          ],
        );

        final container = _containerFor(config);
        addTearDown(container.dispose);

        expect(container.read(marginMetaProvider), contains('my-vps'));
      },
    );

    test('falls back to a source-count summary for more than one host', () {
      const config = AppConfig(
        hosts: [
          SourceEntry(
            kind: SourceKind.host,
            id: 'a',
            provider: 'webdock',
            settings: {'slug': 'a', 'apiToken': 'x'},
          ),
          SourceEntry(
            kind: SourceKind.host,
            id: 'b',
            provider: 'webdock',
            settings: {'slug': 'b', 'apiToken': 'x'},
          ),
        ],
        uptime: [
          SourceEntry(
            kind: SourceKind.uptime,
            id: 'kuma',
            provider: 'kuma',
            settings: {'url': 'https://kuma.test', 'apiKey': 'k'},
          ),
        ],
      );

      final container = _containerFor(config);
      addTearDown(container.dispose);

      expect(
        container.read(marginMetaProvider),
        contains('2 HOSTS · 1 UPTIME'),
      );
    });
  });
}
