import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/net/docker_client_io.dart';

const _socketPath = '/var/run/docker.sock';

void main() {
  final hasSocket = File(_socketPath).existsSync();

  test(
    'connects to a real Docker/Podman unix socket and gets a live response',
    () async {
      final client = dockerHttpClient(const UnixSocket(_socketPath));
      addTearDown(client.close);

      final response = await client
          .get(Uri.parse('http://localhost/v1.44/_ping'))
          .timeout(const Duration(seconds: 5));

      expect(response.statusCode, 200);
      expect(response.body, 'OK');
    },
    skip: hasSocket
        ? false
        : 'no Docker/Podman socket at $_socketPath on this machine',
  );

  test('a nonexistent unix socket path fails the connection', () async {
    final client = dockerHttpClient(
      const UnixSocket('/tmp/kurokan-test-nonexistent.sock'),
    );
    addTearDown(client.close);

    await expectLater(
      client.get(Uri.parse('http://localhost/v1.44/_ping')),
      throwsA(anything),
    );
  });

  test('a Tcp endpoint redirects every request to that host/port, regardless '
      'of the placeholder host the request URI itself carries', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? receivedPath;
    final sub = server.listen((request) {
      receivedPath = request.uri.path;
      request.response
        ..statusCode = 200
        ..write('OK');
      request.response.close();
    });

    final client = dockerHttpClient(Tcp('127.0.0.1', server.port));
    try {
      // Deliberately a placeholder host/port unrelated to the real
      // server: the connectionFactory must redirect regardless.
      final response = await client.get(
        Uri.parse('http://ignored:1/v1.44/_ping'),
      );
      expect(response.statusCode, 200);
      expect(receivedPath, '/v1.44/_ping');
    } finally {
      client.close();
      await sub.cancel();
      await server.close(force: true);
    }
  });
}
