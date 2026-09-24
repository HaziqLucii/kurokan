import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/features/vps/data/webdock_source.dart';
import 'package:kurokan/features/vps/presentation/hosts_provider.dart';

import '../../../helpers/test_config.dart';

void main() {
  test('builds a WebdockSource for the matching host entry id', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          testConfig(webdockSlug: 'my-vps', webdockToken: 'wd_secret'),
        ),
      ],
    );
    addTearDown(container.dispose);

    // 'webdock' is the fixed id testConfig() gives its host entry.
    final source = container.read(hostsSourceProvider('webdock'));

    expect(source, isA<WebdockSource>());
    expect((source as WebdockSource).slug, 'my-vps');
    expect(source.apiToken, 'wd_secret');
  });

  test('throws when the requested source id has no matching host entry', () {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(testConfig())],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(hostsSourceProvider('nonexistent')),
      throwsA(anything),
    );
  });
}
