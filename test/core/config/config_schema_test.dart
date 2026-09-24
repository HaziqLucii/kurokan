import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/config_schema.dart';

import '../../helpers/test_config.dart';

void main() {
  group('SourceEntry', () {
    test('panelKey combines kind and id', () {
      const entry = SourceEntry(
        kind: SourceKind.host,
        id: 'my-vps',
        provider: 'webdock',
        settings: {},
      );
      expect(entry.panelKey, 'host:my-vps');
    });

    test('toJson flattens settings alongside id/provider', () {
      const entry = SourceEntry(
        kind: SourceKind.uptime,
        id: 'kuma',
        provider: 'kuma',
        settings: {'url': 'https://kuma.test', 'apiKey': 'uk1_secret'},
      );
      expect(entry.toJson(), {
        'id': 'kuma',
        'provider': 'kuma',
        'url': 'https://kuma.test',
        'apiKey': 'uk1_secret',
      });
    });

    test('fromJson throws when id is missing', () {
      expect(
        () => SourceEntry.fromJson(
          {'provider': 'webdock', 'slug': 'x', 'apiToken': 'y'},
          kind: SourceKind.host,
          listName: 'hosts',
          index: 0,
          schema: testConfigSchema,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'hosts[0].id is required',
          ),
        ),
      );
    });

    test('fromJson throws when provider is missing', () {
      expect(
        () => SourceEntry.fromJson(
          {'id': 'webdock', 'slug': 'x', 'apiToken': 'y'},
          kind: SourceKind.host,
          listName: 'hosts',
          index: 0,
          schema: testConfigSchema,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'hosts[0].provider is required',
          ),
        ),
      );
    });
  });
}
