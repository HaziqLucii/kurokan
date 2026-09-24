import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/net/http_client_io.dart';
import 'package:kurokan/version.dart';

void main() {
  test('createHttpClient sends the kurokan User-Agent header', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? receivedUserAgent;
    final sub = server.listen((request) {
      receivedUserAgent = request.headers.value('user-agent');
      request.response
        ..statusCode = 200
        ..write('ok');
      request.response.close();
    });

    final client = createHttpClient();
    try {
      await client.get(
        Uri.parse('http://${server.address.address}:${server.port}/'),
      );
    } finally {
      client.close();
      await sub.cancel();
      await server.close(force: true);
    }

    expect(receivedUserAgent, 'kurokan/$appVersion');
  });
}
