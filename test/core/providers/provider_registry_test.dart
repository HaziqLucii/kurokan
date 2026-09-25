import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/core/providers/default_registry.dart';
import 'package:kurokan/core/providers/provider_registry.dart';
import 'package:kurokan/core/providers/provider_spec.dart';
import 'package:kurokan/features/containers/data/docker_spec.dart';
import 'package:kurokan/features/demo/demo_specs.dart';
import 'package:kurokan/features/uptime/data/kuma_spec.dart';
import 'package:kurokan/features/vps/data/prometheus_node_source.dart';
import 'package:kurokan/features/vps/data/prometheus_node_spec.dart';
import 'package:kurokan/features/vps/data/webdock_spec.dart';

SourceDeps _fakeDeps() => SourceDeps(
  client: MockClient((_) async => throw UnimplementedError()),
  clock: clock,
);

/// A dummy value for a required field, distinct enough per [FieldKind] that
/// a constructor doing something field-kind-specific with it (like
/// `Uri.parse`) doesn't itself throw and mask what the test is checking.
String _dummyValueFor(FieldKind kind) => switch (kind) {
  FieldKind.url => 'https://example.test',
  _ => 'test-value',
};

void main() {
  group('ProviderRegistry', () {
    const registry = ProviderRegistry(hosts: [webdockSpec], uptime: [kumaSpec]);

    test('hostSpec/uptimeSpec/containerSpec find by id', () {
      expect(registry.hostSpec('webdock'), same(webdockSpec));
      expect(registry.hostSpec('nonexistent'), isNull);
      expect(registry.uptimeSpec('kuma'), same(kumaSpec));
      expect(registry.containerSpec('docker'), isNull);
    });

    test('ConfigSchema methods delegate to the matching spec', () {
      expect(registry.hostFields('webdock'), webdockSpec.fields);
      expect(registry.hostFields('nonexistent'), isNull);
      expect(registry.uptimeFields('kuma'), kumaSpec.fields);
      expect(registry.containerFields('docker'), isNull);
    });

    test('providerIds lists every known id per kind', () {
      expect(registry.providerIds(SourceKind.host), ['webdock']);
      expect(registry.providerIds(SourceKind.uptime), ['kuma']);
      expect(registry.providerIds(SourceKind.containers), isEmpty);
    });
  });

  test('defaultRegistry contains every shipped provider', () {
    expect(defaultRegistry.hosts, [
      webdockSpec,
      prometheusNodeSpec,
      demoHostSpec,
    ]);
    expect(defaultRegistry.uptime, [kumaSpec, demoUptimeSpec]);
    expect(defaultRegistry.containers, [dockerSpec, demoContainerSpec]);
  });

  // Table-driven guard against the `settings['x']!` runtime-null bug class:
  // if `create()` reads a settings key with no matching FieldSpec, building
  // settings from `fields` alone (not a hand-typed literal that happens to
  // already agree with the code) leaves that key absent, and the `!` in
  // `create()` throws. New specs (Phase 1.3's demo providers, Phase 2's
  // real providers) are covered automatically just by being registered in
  // defaultRegistry, no new test needed per provider.
  group('every registered spec', () {
    final allSpecs = [
      ...defaultRegistry.hosts,
      ...defaultRegistry.uptime,
      ...defaultRegistry.containers,
    ];

    for (final spec in allSpecs) {
      test('${spec.id}: create() only reads keys declared in fields', () {
        final settings = {
          for (final field in spec.fields.where((f) => f.required))
            field.key: _dummyValueFor(field.kind),
        };
        final entry = SourceEntry(
          kind: spec.kind,
          id: spec.id,
          provider: spec.id,
          settings: settings,
        );

        expect(() => spec.create(entry, _fakeDeps()), returnsNormally);
      });

      test(
        '${spec.id}: its fields round-trip through SourceEntry.fromJson',
        () {
          final json = <String, dynamic>{
            'id': spec.id,
            'provider': spec.id,
            for (final field in spec.fields.where((f) => f.required))
              field.key: _dummyValueFor(field.kind),
          };
          final entry = SourceEntry.fromJson(
            json,
            kind: spec.kind,
            listName: 'test',
            index: 0,
            schema: defaultRegistry,
          );

          expect(() => spec.create(entry, _fakeDeps()), returnsNormally);
        },
      );
    }
  });

  group('webdockSpec', () {
    test('label uses the slug', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'webdock',
        provider: 'webdock',
        settings: {'slug': 'my-vps', 'apiToken': 'x'},
      );
      expect(webdockSpec.label(entry), 'my-vps');
    });

    test('label falls back to id when slug is absent', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'my-host-id',
        provider: 'webdock',
        settings: {},
      );
      expect(webdockSpec.label(entry), 'my-host-id');
    });
  });

  group('kumaSpec', () {
    test('label uses the url', () {
      const entry = SourceEntry(
        kind: SourceKind.uptime,
        id: 'kuma',
        provider: 'kuma',
        settings: {'url': 'https://kuma.test', 'apiKey': 'x'},
      );
      expect(kumaSpec.label(entry), 'https://kuma.test');
    });

    test('label falls back to id when url is absent', () {
      const entry = SourceEntry(
        kind: SourceKind.uptime,
        id: 'my-uptime-id',
        provider: 'kuma',
        settings: {},
      );
      expect(kumaSpec.label(entry), 'my-uptime-id');
    });
  });

  group('prometheusNodeSpec', () {
    test('label uses the url', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'prom',
        provider: 'prometheus',
        settings: {'url': 'http://prom.test:9090'},
      );
      expect(prometheusNodeSpec.label(entry), 'http://prom.test:9090');
    });

    test('label falls back to id when url is absent', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'my-prom-id',
        provider: 'prometheus',
        settings: {},
      );
      expect(prometheusNodeSpec.label(entry), 'my-prom-id');
    });

    test('create() only sets auth when authToken is present', () {
      const withoutToken = SourceEntry(
        kind: SourceKind.host,
        id: 'prom',
        provider: 'prometheus',
        settings: {'url': 'http://prom.test:9090'},
      );
      const withToken = SourceEntry(
        kind: SourceKind.host,
        id: 'prom',
        provider: 'prometheus',
        settings: {'url': 'http://prom.test:9090', 'authToken': 'tok'},
      );

      final noAuth =
          prometheusNodeSpec.create(withoutToken, _fakeDeps())
              as PrometheusNodeSource;
      final withAuth =
          prometheusNodeSpec.create(withToken, _fakeDeps())
              as PrometheusNodeSource;

      expect(noAuth.auth, isNull);
      expect(withAuth.auth?.bearerToken, 'tok');
    });

    test('create() parses networkQuotaGiB when present', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'prom',
        provider: 'prometheus',
        settings: {'url': 'http://prom.test:9090', 'networkQuotaGiB': '2000'},
      );
      final source =
          prometheusNodeSpec.create(entry, _fakeDeps()) as PrometheusNodeSource;
      expect(source.networkQuotaGiB, 2000);
    });
  });

  group('demo specs', () {
    test('demoHostSpec.label is always "Demo data"', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'demo-host',
        provider: 'demo',
        settings: {},
      );
      expect(demoHostSpec.label(entry), 'Demo data');
    });

    test('demoUptimeSpec.label is always "Demo data"', () {
      const entry = SourceEntry(
        kind: SourceKind.uptime,
        id: 'demo-uptime',
        provider: 'demo',
        settings: {},
      );
      expect(demoUptimeSpec.label(entry), 'Demo data');
    });

    test('demoContainerSpec.label is always "Demo data"', () {
      const entry = SourceEntry(
        kind: SourceKind.containers,
        id: 'demo-containers',
        provider: 'demo',
        settings: {},
      );
      expect(demoContainerSpec.label(entry), 'Demo data');
    });
  });

  group('dockerSpec', () {
    test('label uses the endpoint setting when present', () {
      const entry = SourceEntry(
        kind: SourceKind.containers,
        id: 'docker',
        provider: 'docker',
        settings: {'endpoint': 'unix:///custom/docker.sock'},
      );
      expect(dockerSpec.label(entry), 'unix:///custom/docker.sock');
    });

    test('label falls back to "Docker" for auto/absent endpoint', () {
      const withoutSetting = SourceEntry(
        kind: SourceKind.containers,
        id: 'docker',
        provider: 'docker',
        settings: {},
      );
      const withAuto = SourceEntry(
        kind: SourceKind.containers,
        id: 'docker',
        provider: 'docker',
        settings: {'endpoint': 'auto'},
      );
      expect(dockerSpec.label(withoutSetting), 'Docker');
      expect(dockerSpec.label(withAuto), 'Docker');
    });
  });
}
