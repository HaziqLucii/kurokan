import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/net/docker_client_io.dart';
import 'package:kurokan/features/containers/data/docker_endpoint_discovery.dart';

bool _noneExist(String path) => false;

void main() {
  test('an explicit non-auto setting is treated as a unix socket path', () {
    final endpoint = resolveDockerEndpoint(
      '/custom/docker.sock',
      env: const {},
      exists: _noneExist,
    );
    expect(endpoint, isA<UnixSocket>());
    expect((endpoint as UnixSocket).path, '/custom/docker.sock');
  });

  test('an explicit unix:// setting parses to that path', () {
    final endpoint = resolveDockerEndpoint(
      'unix:///run/podman/podman.sock',
      env: const {},
      exists: _noneExist,
    );
    expect(endpoint, isA<UnixSocket>());
    expect((endpoint as UnixSocket).path, '/run/podman/podman.sock');
  });

  test('an explicit tcp:// setting parses to host/port', () {
    final endpoint = resolveDockerEndpoint(
      'tcp://192.168.1.10:2375',
      env: const {},
      exists: _noneExist,
    );
    expect(endpoint, isA<Tcp>());
    expect((endpoint as Tcp).host, '192.168.1.10');
    expect(endpoint.port, 2375);
  });

  test('a setting that Uri.tryParse can\'t even parse falls back to treating '
      'it as a raw unix socket path', () {
    final endpoint = resolveDockerEndpoint(
      '::::',
      env: const {},
      exists: _noneExist,
    );
    expect(endpoint, isA<UnixSocket>());
    expect((endpoint as UnixSocket).path, '::::');
  });

  test('a tcp:// setting without an explicit port defaults to 2375', () {
    final endpoint =
        resolveDockerEndpoint(
              'tcp://vps.example.tld',
              env: const {},
              exists: _noneExist,
            )
            as Tcp;
    expect(endpoint.port, 2375);
  });

  group('setting is "auto" (or empty)', () {
    test('DOCKER_HOST takes priority over every socket candidate', () {
      final endpoint = resolveDockerEndpoint(
        'auto',
        env: const {'DOCKER_HOST': 'unix:///env/docker.sock'},
        exists: (_) => true,
      );
      expect(endpoint, isA<UnixSocket>());
      expect((endpoint as UnixSocket).path, '/env/docker.sock');
    });

    test('without DOCKER_HOST, the first existing candidate wins, in the '
        'documented priority order', () {
      final endpoint = resolveDockerEndpoint(
        'auto',
        env: const {'HOME': '/home/haziq'},
        exists: (path) => path == '/home/haziq/.orbstack/run/docker.sock',
      );
      expect(endpoint, isA<UnixSocket>());
      expect(
        (endpoint as UnixSocket).path,
        '/home/haziq/.orbstack/run/docker.sock',
      );
    });

    test(
      '/var/run/docker.sock is checked before any HOME-relative candidate',
      () {
        final endpoint = resolveDockerEndpoint(
          'auto',
          env: const {'HOME': '/home/haziq'},
          exists: (_) => true,
        );
        expect((endpoint as UnixSocket).path, '/var/run/docker.sock');
      },
    );

    test('XDG_RUNTIME_DIR/docker.sock is a candidate when set', () {
      final endpoint = resolveDockerEndpoint(
        'auto',
        env: const {'XDG_RUNTIME_DIR': '/run/user/1000'},
        exists: (path) => path == '/run/user/1000/docker.sock',
      );
      expect((endpoint as UnixSocket).path, '/run/user/1000/docker.sock');
    });

    test(
      'a podman socket under /run/user/\$UID is a candidate when UID is set',
      () {
        final endpoint = resolveDockerEndpoint(
          'auto',
          env: const {'UID': '1000'},
          exists: (path) => path == '/run/user/1000/podman/podman.sock',
        );
        expect(
          (endpoint as UnixSocket).path,
          '/run/user/1000/podman/podman.sock',
        );
      },
    );

    test('no candidate exists: falls back to /var/run/docker.sock so the '
        'resulting error is a clear connection failure, not a dead end', () {
      final endpoint = resolveDockerEndpoint(
        'auto',
        env: const {},
        exists: _noneExist,
      );
      expect((endpoint as UnixSocket).path, '/var/run/docker.sock');
    });

    test('an empty setting string is treated the same as "auto"', () {
      final endpoint = resolveDockerEndpoint(
        '',
        env: const {'DOCKER_HOST': 'unix:///env/docker.sock'},
        exists: _noneExist,
      );
      expect((endpoint as UnixSocket).path, '/env/docker.sock');
    });
  });
}
