import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/config/config_provider.dart';
import 'package:kurokan/core/config/config_schema.dart';
import 'package:kurokan/features/containers/data/docker_source.dart';
import 'package:kurokan/features/containers/presentation/containers_provider.dart';

const _config = AppConfig(
  containers: [
    SourceEntry(
      kind: SourceKind.containers,
      id: 'docker',
      provider: 'docker',
      settings: {},
    ),
  ],
);

void main() {
  test('builds a DockerSource for the matching container entry id', () {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(_config)],
    );
    addTearDown(container.dispose);

    final source = container.read(containersSourceProvider('docker'));

    expect(source, isA<DockerSource>());
  });

  test(
    'throws when the requested source id has no matching containers entry',
    () {
      final container = ProviderContainer(
        overrides: [appConfigProvider.overrideWithValue(_config)],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(containersSourceProvider('nonexistent')),
        throwsA(anything),
      );
    },
  );
}
