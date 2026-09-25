import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kurokan/core/net/fetch_error.dart';
import 'package:kurokan/features/uptime/data/prometheus_text_parser.dart';
import 'package:kurokan/features/uptime/data/uptime_kuma_metrics_source.dart';
import 'package:kurokan/features/uptime/domain/monitor_status.dart';

const _validBody = '''
monitor_status{monitor_name="Docs",monitor_type="http"} 1
monitor_response_time{monitor_name="Docs",monitor_type="http"} 112
''';

class _ThrowingParser extends PrometheusMetricsParser {
  @override
  ParseResult parse(String body) =>
      throw const FormatException('synthetic parse failure');
}

UptimeKumaMetricsSource _sourceWith(
  http.Client client, {
  PrometheusMetricsParser? parser,
}) => UptimeKumaMetricsSource(
  url: 'https://status.example.tld',
  apiKey: 'uk1_secret',
  client: client,
  parser: parser,
);

void main() {
  test(
    'sends HTTP Basic auth with an empty username and the API key as the password',
    () async {
      late Map<String, String> capturedHeaders;
      final client = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(_validBody, 200);
      });

      await _sourceWith(client).fetch();

      final expected = 'Basic ${base64Encode(utf8.encode(":uk1_secret"))}';
      expect(capturedHeaders['Authorization'], expected);
    },
  );

  test('parses a 200 response into MonitorStatus list', () async {
    final client = MockClient(
      (request) async => http.Response(_validBody, 200),
    );
    final monitors = await _sourceWith(client).fetch();

    expect(monitors, hasLength(1));
    expect(monitors.single.name, 'Docs');
    expect(monitors.single.state, MonitorState.up);
  });

  test('throws AuthError on 401', () async {
    final client = MockClient(
      (request) async => http.Response('unauthorized', 401),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<AuthError>()));
  });

  test('throws HttpError on a non-200/401 status', () async {
    final client = MockClient(
      (request) async => http.Response('bad gateway', 502),
    );
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 502)),
    );
  });

  test('throws ParseError when the parser itself throws', () async {
    final client = MockClient(
      (request) async => http.Response(_validBody, 200),
    );
    await expectLater(
      _sourceWith(client, parser: _ThrowingParser()).fetch,
      throwsA(isA<ParseError>()),
    );
  });

  test('throws NetworkError on a SocketException', () async {
    final client = MockClient(
      (request) async => throw const SocketException('Connection refused'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test(
    'throws NetworkError on a ClientException (how IOClient surfaces most connection failures)',
    () async {
      final client = MockClient(
        (request) async => throw http.ClientException('Connection closed'),
      );
      await expectLater(
        _sourceWith(client).fetch,
        throwsA(isA<NetworkError>()),
      );
    },
  );

  test('throws NetworkError on a TLS handshake failure', () async {
    final client = MockClient(
      (request) async => throw const HandshakeException('cert verify failed'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<NetworkError>()));
  });

  test('throws TimeoutError when the request times out', () async {
    final client = MockClient(
      (request) async => throw TimeoutException('timed out'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<TimeoutError>()));
  });
}
