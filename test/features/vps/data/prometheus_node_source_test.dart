import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kurokan/core/net/fetch_error.dart';
import 'package:kurokan/features/vps/data/prometheus_node_source.dart';
import 'package:kurokan/features/vps/domain/host_vitals.dart';

String _fixture(String name) =>
    File('test/fixtures/prometheus/$name.json').readAsStringSync();

const _emptyVector =
    '{"status":"success","data":{"resultType":"vector","result":[]}}';

/// Routes a `/api/v1/query?query=...` request to the fixture matching its
/// `query` param. Order matters: some substrings are prefixes of another
/// query's full text (e.g. plain `node_memory_MemTotal_bytes` vs the
/// subtraction expression that also contains it), so the more specific
/// check runs first.
http.Response _routeFixture(Uri url) {
  final query = url.queryParameters['query'] ?? '';
  String body;
  if (query.contains('node_uname_info')) {
    body = _fixture('uname');
  } else if (query.contains('node_cpu_seconds_total')) {
    body = _fixture('cpu');
  } else if (query.contains('MemAvailable')) {
    body = _fixture('mem_used');
  } else if (query.contains('MemTotal')) {
    body = _fixture('mem_total');
  } else if (query.contains('node_filesystem_size_bytes')) {
    body = _fixture('disk_total');
  } else if (query.contains('node_filesystem_avail_bytes')) {
    body = _fixture('disk_avail');
  } else if (query.contains('node_network_receive_bytes_total')) {
    body = _fixture('net_rx');
  } else if (query.contains('node_network_transmit_bytes_total')) {
    body = _fixture('net_tx');
  } else if (query == 'node_load1' || query.contains('node_load1{')) {
    body = _fixture('load1');
  } else if (query == 'node_load5' || query.contains('node_load5{')) {
    body = _fixture('load5');
  } else if (query == 'node_load15' || query.contains('node_load15{')) {
    body = _fixture('load15');
  } else if (query.contains('node_boot_time_seconds')) {
    body = _fixture('uptime');
  } else if (query.contains('node_procs_running')) {
    body = _fixture('procs');
  } else if (query == 'up' || query.contains('up{')) {
    body = _fixture('up');
  } else {
    body = _emptyVector;
  }
  return http.Response(body, 200);
}

http.Client _fixtureClient() =>
    MockClient((request) async => _routeFixture(request.url));

PrometheusNodeSource _sourceWith(
  http.Client client, {
  PromAuth? auth,
  String? job,
  String? instanceRegex,
  double? networkQuotaGiB,
}) => PrometheusNodeSource(
  url: 'http://prom.test:9090',
  auth: auth,
  job: job,
  instanceRegex: instanceRegex,
  networkQuotaGiB: networkQuotaGiB,
  client: client,
);

void main() {
  test(
    'fetches every metric and maps two hosts, joined by the instance label',
    () async {
      final hosts = await _sourceWith(_fixtureClient()).fetch();

      expect(hosts, hasLength(2));
      final web1 = hosts.firstWhere((h) => h.slug == '203.0.113.10:9100');
      final web2 = hosts.firstWhere((h) => h.slug == '203.0.113.11:9100');

      expect(web1.name, 'web-1');
      expect(web1.status, 'running');
      expect(web1.cpu.percentUsed, 82.0);
      expect(web1.cpu.level, UsageLevel.warn);
      expect(web1.memory!.level, UsageLevel.ok);
      expect(web1.disk!.level, UsageLevel.warn);
      expect(web1.processCount, 3);
      expect(web1.extra, {
        'load1': '0.42',
        'load5': '0.31',
        'load15': '0.20',
        'uptimeSeconds': '123457',
      });

      expect(web2.name, 'web-2');
      expect(web2.status, 'error');
      expect(web2.cpu.percentUsed, 5.1);
      expect(web2.cpu.level, UsageLevel.ok);
      expect(web2.memory!.level, UsageLevel.crit);
      expect(web2.disk!.level, UsageLevel.crit);
      expect(web2.processCount, 1);
    },
  );

  test(
    'memory/disk gauges are in MiB (byte metrics divided by 1024*1024)',
    () async {
      final hosts = await _sourceWith(_fixtureClient()).fetch();
      final web1 = hosts.firstWhere((h) => h.slug == '203.0.113.10:9100');

      // mem_total.json: 4294967296 bytes = 4096 MiB
      expect(web1.memory!.allowed, closeTo(4096, 0.001));
      // disk_total.json: 51539607552 bytes = 49152 MiB
      expect(web1.disk!.allowed, closeTo(49152, 0.001));
    },
  );

  test(
    'network gauge sums receive+transmit (bytes -> GiB) and is unavailable without a configured quota',
    () async {
      final unquota = await _sourceWith(_fixtureClient()).fetch();
      final host = unquota.firstWhere((h) => h.slug == '203.0.113.10:9100');
      // With no networkQuotaGiB, HostVitals.network is non-null but has no
      // allowed/percent (an unbounded resource), matching Gauge's own
      // documented "no cap" convention rather than a crash.
      expect(host.network!.allowed, isNull);
      expect(host.network!.percentUsed, isNull);
      // net_rx 500000000.5 + net_tx 300000000.25 bytes -> GiB
      expect(
        host.network!.used,
        closeTo((500000000.5 + 300000000.25) / (1024 * 1024 * 1024), 1e-6),
      );

      final quota = await _sourceWith(
        _fixtureClient(),
        networkQuotaGiB: 2000,
      ).fetch();
      final hostWithQuota = quota.firstWhere(
        (h) => h.slug == '203.0.113.10:9100',
      );
      expect(hostWithQuota.network!.allowed, 2000);
      expect(hostWithQuota.network!.percentUsed, isNotNull);
    },
  );

  test(
    'an empty result vector for one metric degrades just that gauge to null, not a fetch failure',
    () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['query'] ?? '';
        if (query.contains('node_filesystem_size_bytes')) {
          return http.Response(_emptyVector, 200);
        }
        return _routeFixture(request.url);
      });

      final hosts = await _sourceWith(client).fetch();
      final web1 = hosts.firstWhere((h) => h.slug == '203.0.113.10:9100');
      expect(web1.disk, isNull);
      // Every other gauge for the same host is unaffected.
      expect(web1.memory, isNotNull);
      expect(web1.cpu.percentUsed, isNotNull);
    },
  );

  test(
    'an empty node_uname_info vector yields zero hosts, not an error (no crash on an empty host set)',
    () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['query'] ?? '';
        if (query.contains('node_uname_info')) {
          return http.Response(_emptyVector, 200);
        }
        return _routeFixture(request.url);
      });

      final hosts = await _sourceWith(client).fetch();
      expect(hosts, isEmpty);
    },
  );

  test(
    'sends a Bearer token when PromAuth is given, none when it is not',
    () async {
      final headersSeen = <String?>[];
      final client = MockClient((request) async {
        headersSeen.add(request.headers['Authorization']);
        return _routeFixture(request.url);
      });

      await _sourceWith(client).fetch();
      expect(headersSeen, everyElement(isNull));

      headersSeen.clear();
      await _sourceWith(
        client,
        auth: const PromAuth(bearerToken: 'secret-token'),
      ).fetch();
      expect(headersSeen, everyElement('Bearer secret-token'));
    },
  );

  test(
    'job and instanceRegex settings are folded into every query as label matchers',
    () async {
      final queriesSent = <String>[];
      final client = MockClient((request) async {
        queriesSent.add(request.url.queryParameters['query'] ?? '');
        return http.Response(_emptyVector, 200);
      });

      await _sourceWith(client, job: 'node', instanceRegex: '10\\..*').fetch();

      expect(queriesSent, isNotEmpty);
      for (final q in queriesSent) {
        expect(q, contains('job="node"'));
        expect(q, contains('instance=~"10\\..*"'));
      }
    },
  );

  test('throws AuthError on 401', () async {
    final client = MockClient((request) async => http.Response('', 401));
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(
        isA<AuthError>().having((e) => e.service, 'service', 'PROMETHEUS'),
      ),
    );
  });

  test('throws HttpError on a non-200, non-auth status', () async {
    final client = MockClient((request) async => http.Response('', 503));
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 503)),
    );
  });

  test(
    'throws ParseError when Prometheus reports a query error inside a 200',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'status': 'error',
            'errorType': 'bad_data',
            'error': 'invalid parameter "query"',
          }),
          200,
        ),
      );
      await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
    },
  );

  test('throws ParseError on a non-JSON body', () async {
    final client = MockClient(
      (request) async => http.Response('not json', 200),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
  });

  test('throws NetworkError on a SocketException', () async {
    final client = MockClient(
      (request) async => throw const SocketException('Connection refused'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test('throws NetworkError on a ClientException', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('Connection closed'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test('throws TimeoutError when the request times out', () async {
    final client = MockClient(
      (request) async => throw TimeoutException('timed out'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<TimeoutError>()));
  });

  test('throws NetworkError on an HttpException', () async {
    final client = MockClient(
      (request) async => throw const HttpException('reset'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test('throws NetworkError on a TlsException', () async {
    final client = MockClient(
      (request) async => throw const TlsException('handshake failed'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test(
    'throws ParseError when the result is not an instant vector (e.g. a range query response)',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'status': 'success',
            'data': {'resultType': 'matrix', 'result': []},
          }),
          200,
        ),
      );
      await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
    },
  );
}
