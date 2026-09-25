import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kurokan/core/net/fetch_error.dart';
import 'package:kurokan/features/containers/data/docker_source.dart';
import 'package:kurokan/features/containers/domain/container_status.dart';

String _fixture(String name) =>
    File('test/fixtures/docker/$name.json').readAsStringSync();

const _apiId =
    'e2105c3c79c34999bf0bb095bfb66cb0a0a9c4622f938b9337e1967dc213e351';
const _webId =
    'b42cdaf9ca6b37ed9f56dfb916767120fbfe6000c93b33a09b77d8dc76b6a1b9';
const _migrateId =
    'ef2c8dca12ef3541fe8d9b28157449234cb8272a5c4b4b32f2bb4a0c1c9ead0e';
const _setupId =
    '38a791146ddd8de62d7b3095a24e9bd94fb63942cb0e7f81e943811f5f227c8e';

final _inspectById = {
  _apiId: 'inspect_running',
  _webId: 'inspect_running_no_health',
  _migrateId: 'inspect_exited',
  _setupId: 'inspect_created',
};

final _statsById = {
  _apiId: 'stats',
  _webId: 'stats',
  _migrateId: 'stats_stopped',
  _setupId: 'stats_stopped',
};

DockerSource _sourceWith(
  http.Client client, {
  StatsMode stats = StatsMode.full,
}) => DockerSource(client: client, stats: stats);

/// Routes a request path to the matching fixture response, exactly the way
/// the real Docker API is laid out. A single shared function (not a nested
/// `MockClient`) since an `http.Request` can only be finalized once: handing
/// the same request to a second `MockClient.send()` throws "Can't finalize a
/// finalized Request."
http.Response _respond(
  String path, {
  int pingStatus = 200,
  int infoStatus = 200,
  int listStatus = 200,
  Map<String, int> inspectStatus = const {},
  Map<String, int> statsStatus = const {},
}) {
  if (path.endsWith('/_ping')) return http.Response('OK', pingStatus);
  if (path.endsWith('/info')) {
    return http.Response(_fixture('info'), infoStatus);
  }
  if (path.endsWith('/containers/json')) {
    return http.Response(_fixture('containers_json'), listStatus);
  }
  final inspectMatch = RegExp(r'/containers/([^/]+)/json$').firstMatch(path);
  if (inspectMatch != null) {
    final id = inspectMatch.group(1)!;
    return http.Response(_fixture(_inspectById[id]!), inspectStatus[id] ?? 200);
  }
  final statsMatch = RegExp(r'/containers/([^/]+)/stats$').firstMatch(path);
  if (statsMatch != null) {
    final id = statsMatch.group(1)!;
    return http.Response(_fixture(_statsById[id]!), statsStatus[id] ?? 200);
  }
  throw StateError('unexpected request path: $path');
}

http.Client _fixtureClient({
  int pingStatus = 200,
  int infoStatus = 200,
  int listStatus = 200,
  Map<String, int> inspectStatus = const {},
  Map<String, int> statsStatus = const {},
}) => MockClient(
  (request) async => _respond(
    request.url.path,
    pingStatus: pingStatus,
    infoStatus: infoStatus,
    listStatus: listStatus,
    inspectStatus: inspectStatus,
    statsStatus: statsStatus,
  ),
);

void main() {
  test('fetches the list, then inspect+stats per container, and merges them '
      'into ContainerStatus', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      return _respond(request.url.path);
    });

    final containers = await _sourceWith(client).fetch();

    expect(requestedPaths, contains('/v1.44/_ping'));
    expect(requestedPaths, contains('/v1.44/info'));
    expect(requestedPaths, contains('/v1.44/containers/json'));
    expect(containers, hasLength(4));

    final api = containers.firstWhere((c) => c.name == 'api');
    expect(api.state, ContainerState.running);
    expect(api.health, HealthState.healthy);
    expect(api.restartCount, 2);
    expect(api.cpuPercent, closeTo(20.0, 0.01));
    expect(api.startedAt, isNotNull);

    final web = containers.firstWhere((c) => c.name == 'web');
    expect(web.health, HealthState.none);

    final migrate = containers.firstWhere((c) => c.name == 'migrate');
    expect(migrate.state, ContainerState.exited);
    expect(migrate.cpuPercent, isNull);
    expect(migrate.memUsed, isNull);

    final setup = containers.firstWhere((c) => c.name == 'setup');
    expect(setup.state, ContainerState.created);
    expect(setup.startedAt, isNull);
  });

  test('StatsMode.none skips every per-container request', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      return _respond(request.url.path);
    });

    final containers = await _sourceWith(client, stats: StatsMode.none).fetch();

    expect(containers, hasLength(4));
    for (final c in containers) {
      expect(c.health, HealthState.none);
      expect(c.restartCount, 0);
      expect(c.cpuPercent, isNull);
      expect(c.startedAt, isNull);
    }
    expect(
      requestedPaths.where(
        (p) => p.contains('/json') && p != '/v1.44/containers/json',
      ),
      isEmpty,
    );
    expect(requestedPaths.where((p) => p.contains('/stats')), isEmpty);
  });

  test('a single container whose inspect call fails still returns a status '
      'for every container, degrading just that one to defaults', () async {
    final client = _fixtureClient(inspectStatus: {_apiId: 500});
    final containers = await _sourceWith(client).fetch();

    expect(containers, hasLength(4));
    final api = containers.firstWhere((c) => c.name == 'api');
    expect(api.state, ContainerState.running); // from the list, unaffected
    expect(api.health, HealthState.none); // inspect failed, degraded
    expect(api.restartCount, 0);
  });

  test('a single container whose stats call fails still returns a status for '
      'every container, degrading just that one to null gauges', () async {
    final client = _fixtureClient(statsStatus: {_apiId: 500});
    final containers = await _sourceWith(client).fetch();

    final api = containers.firstWhere((c) => c.name == 'api');
    expect(api.cpuPercent, isNull);
    expect(api.health, HealthState.healthy); // inspect still succeeded
  });

  test('a per-container stats call that hangs past 3s degrades that '
      'container\'s gauges to null rather than failing the whole fetch '
      '(inspect for the same container still succeeds normally)', () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/containers/$_apiId/stats')) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
      return _respond(path);
    });

    final containers = await _sourceWith(client).fetch();
    expect(containers, hasLength(4));
    final api = containers.firstWhere((c) => c.name == 'api');
    expect(api.health, HealthState.healthy); // inspect: unaffected
    expect(api.restartCount, 2); // inspect: unaffected
    expect(api.cpuPercent, isNull); // stats: timed out, degraded
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('throws AuthError on 401 from /_ping', () async {
    final client = _fixtureClient(pingStatus: 401);
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<AuthError>().having((e) => e.service, 'service', 'DOCKER')),
    );
  });

  test('throws HttpError on a non-200 from /containers/json', () async {
    final client = _fixtureClient(listStatus: 500);
    await expectLater(
      _sourceWith(client).fetch,
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 500)),
    );
  });

  test(
    'throws ParseError when the container list is not a JSON array',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/containers/json')) {
          return http.Response('{"not": "a list"}', 200);
        }
        return _respond(request.url.path);
      });
      await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
    },
  );

  test('throws NetworkError on a SocketException reaching /_ping', () async {
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

  test(
    'throws ParseError when a response body is not valid JSON at all '
    '(distinct from valid-JSON-but-wrong-shape, checked separately)',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/info')) {
          return http.Response('not json at all', 200);
        }
        return _respond(request.url.path);
      });
      await expectLater(_sourceWith(client).fetch, throwsA(isA<ParseError>()));
    },
  );

  test('maps every containers/json State string to its ContainerState, '
      'including dead/paused/restarting and an unrecognized value', () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/containers/json')) {
        return http.Response('''
[
  {"Id": "a", "Names": ["/a"], "Image": "x", "State": "dead"},
  {"Id": "b", "Names": ["/b"], "Image": "x", "State": "paused"},
  {"Id": "c", "Names": ["/c"], "Image": "x", "State": "restarting"},
  {"Id": "d", "Names": ["/d"], "Image": "x", "State": "something-new"}
]
''', 200);
      }
      return _respond(path);
    });

    final containers = await _sourceWith(client, stats: StatsMode.none).fetch();
    final byName = {for (final c in containers) c.name: c.state};
    expect(byName['a'], ContainerState.dead);
    expect(byName['b'], ContainerState.paused);
    expect(byName['c'], ContainerState.restarting);
    expect(byName['d'], ContainerState.unknown);
  });

  test('throws TimeoutError when /_ping itself times out', () async {
    final client = MockClient(
      (request) async => throw TimeoutException('timed out'),
    );
    await expectLater(_sourceWith(client).fetch, throwsA(isA<TimeoutError>()));
  });

  test('an empty container list returns an empty list, not an error', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/containers/json')) {
        return http.Response('[]', 200);
      }
      return _respond(request.url.path);
    });
    expect(await _sourceWith(client).fetch(), isEmpty);
  });
}
