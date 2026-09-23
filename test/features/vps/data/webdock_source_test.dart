import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kurokan/core/net/fetch_error.dart';
import 'package:kurokan/features/vps/data/webdock_source.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';

final _serverBody = File('test/fixtures/webdock_server.json').readAsStringSync();
final _metricsBody = File('test/fixtures/webdock_metrics_now.json').readAsStringSync();

WebdockSource _sourceWith(http.Client client) => WebdockSource(
      slug: 'demo-server',
      apiToken: 'wd_secret',
      client: client,
    );

http.Client _fixtureClient({int serverStatus = 200, int metricsStatus = 200}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/metrics/now')) {
      return http.Response(_metricsBody, metricsStatus);
    }
    return http.Response(_serverBody, serverStatus);
  });
}

void main() {
  test('sends a Bearer token to both endpoints and parses HostVitals', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      expect(request.headers['Authorization'], 'Bearer wd_secret');
      if (request.url.path.endsWith('/metrics/now')) {
        return http.Response(_metricsBody, 200);
      }
      return http.Response(_serverBody, 200);
    });

    final vitals = await _sourceWith(client).fetch();

    expect(requestedPaths, containsAll(['/v1/servers/demo-server', '/v1/servers/demo-server/metrics/now']));
    expect(vitals.slug, 'demo-server');
    expect(vitals.name, 'Demo Server');
    expect(vitals.status, 'running');
    expect(vitals.ipv4, '203.0.113.10');
    expect(vitals.processCount, 214);
    expect(vitals.sampledAt.toUtc(), DateTime.parse('2026-09-23T10:30:00Z'));

    expect(vitals.cpu.percentUsed, 49);
    expect(vitals.cpu.level, UsageLevel.ok);
    expect(vitals.disk.percentUsed, 72.33);
    expect(vitals.disk.level, UsageLevel.warn);
    expect(vitals.memory.percentUsed, 71.8);
    expect(vitals.network.percentUsed, 0.27);
  });

  test('throws AuthError on 401', () async {
    final client = _fixtureClient(serverStatus: 401);
    await expectLater(_sourceWith(client).fetch, throwsA(isA<AuthError>()));
  });

  test('throws AuthError on 401 from the metrics endpoint even when the server endpoint is 200', () async {
    final client = _fixtureClient(metricsStatus: 401);
    await expectLater(_sourceWith(client).fetch, throwsA(isA<AuthError>()));
  });

  test('throws AuthError on 403 (token valid but missing read:servers scope)', () async {
    final client = _fixtureClient(serverStatus: 403);
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<AuthError>().having((e) => e.status, 'status', 403)),
    );
  });

  test('throws HttpError on 404 (server not found)', () async {
    final client = _fixtureClient(serverStatus: 404);
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 404)),
    );
  });

  test('throws HttpError on 429 (no special-casing; the spec never names one)', () async {
    final client = _fixtureClient(metricsStatus: 429);
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 429)),
    );
  });

  test('throws ParseError when a required field is missing from the response', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/metrics/now')) {
        return http.Response(_metricsBody, 200);
      }
      return http.Response('{"name": "no slug field"}', 200);
    });
    await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
  });

  test('throws ParseError when a required field is missing from the metrics response', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/metrics/now')) {
        return http.Response('{"cpu": {}}', 200);
      }
      return http.Response(_serverBody, 200);
    });
    await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
  });

  test('processCount is null (not zero) when the processes block is absent', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/metrics/now')) {
        return http.Response(_metricsBody.replaceAll('"processes"', '"_processes"'), 200);
      }
      return http.Response(_serverBody, 200);
    });
    final vitals = await _sourceWith(client).fetch();
    expect(vitals.processCount, isNull);
  });

  test('sampledAt is converted to local time', () async {
    final client = _fixtureClient();
    final vitals = await _sourceWith(client).fetch();
    expect(vitals.sampledAt.isUtc, isFalse);
    expect(vitals.sampledAt.toUtc(), DateTime.parse('2026-09-23T10:30:00Z'));
  });

  test('throws ParseError on a non-JSON body (e.g. wrong host answering with HTML)', () async {
    final client = MockClient((request) async => http.Response('<html>Not Found</html>', 200));
    await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
  });

  test('throws NetworkError on a SocketException', () async {
    final client = MockClient((request) async => throw const SocketException('Connection refused'));
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test('throws NetworkError on a ClientException', () async {
    final client = MockClient((request) async => throw http.ClientException('Connection closed'));
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test('throws TimeoutError when the request times out', () async {
    final client = MockClient((request) async => throw TimeoutException('timed out'));
    await expectLater(_sourceWith(client).fetch, throwsA(isA<TimeoutError>()));
  });
}
