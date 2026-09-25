import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/net/fetch_error.dart';
import '../domain/container_status.dart';
import 'docker_dto.dart';

enum StatsMode {
  /// Inspect + stats per container: restart count, health, uptime, CPU%, MEM.
  full,

  /// Only the container list: state and name, nothing per-container. Fast,
  /// and the only mode that makes sense against a very large fleet.
  none,
}

class DockerSource implements ContainerSource {
  final http.Client client;
  final String apiVersion;
  final StatsMode stats;
  final int concurrency;

  const DockerSource({
    required this.client,
    this.apiVersion = 'v1.44',
    this.stats = StatsMode.full,
    this.concurrency = 4,
  });

  @override
  Future<List<ContainerStatus>> fetch() async {
    await _get('/_ping');
    // Not surfaced anywhere: ContainerSource.fetch() only returns the
    // container list (per the plan's own interface), so /info's Name/NCPU/
    // MemTotal/ContainersRunning have nowhere to go yet. Kept as an early
    // sanity check that the daemon responds sensibly, same reasoning as
    // /_ping, before spending a request on the (larger) container list.
    await _getJson('/info');

    final listBody = await _getJson('/containers/json?all=1');
    if (listBody is! List) {
      throw const ParseError('containers/json: expected a JSON array');
    }
    final summaries = listBody
        .cast<Map<String, dynamic>>()
        .map(DockerContainerSummaryDTO.fromJson)
        .toList();

    if (stats == StatsMode.none) {
      return [for (final s in summaries) _toStatus(s, null, null)];
    }

    return _mapConcurrent(summaries, concurrency, (s) async {
      final inspect = await _tryInspect(s.id);
      final statsDto = await _tryStats(s.id);
      return _toStatus(s, inspect, statsDto);
    });
  }

  // A single straggler container's inspect/stats call timing out or
  // erroring degrades just that container's extra detail to defaults; it
  // must never fail the whole panel.
  Future<DockerContainerInspectDTO?> _tryInspect(String id) async {
    try {
      final json = await _getJson(
        '/containers/$id/json',
      ).timeout(const Duration(seconds: 3));
      return DockerContainerInspectDTO.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<DockerStatsDTO?> _tryStats(String id) async {
    try {
      final json = await _getJson(
        '/containers/$id/stats?stream=false',
      ).timeout(const Duration(seconds: 3));
      return DockerStatsDTO.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  ContainerStatus _toStatus(
    DockerContainerSummaryDTO s,
    DockerContainerInspectDTO? inspect,
    DockerStatsDTO? statsDto,
  ) => ContainerStatus(
    id: s.id,
    name: s.name,
    image: s.image,
    state: _stateFromString(s.state),
    health: _healthFromString(inspect?.healthStatus),
    restartCount: inspect?.restartCount ?? 0,
    cpuPercent: statsDto?.cpuPercent,
    memUsed: statsDto?.memUsed,
    memLimit: statsDto?.memLimit,
    startedAt: inspect?.startedAt,
  );

  static ContainerState _stateFromString(String s) => switch (s) {
    'running' => ContainerState.running,
    'exited' => ContainerState.exited,
    'paused' => ContainerState.paused,
    'restarting' => ContainerState.restarting,
    'created' => ContainerState.created,
    'dead' => ContainerState.dead,
    _ => ContainerState.unknown,
  };

  static HealthState _healthFromString(String? s) => switch (s) {
    'healthy' => HealthState.healthy,
    'unhealthy' => HealthState.unhealthy,
    'starting' => HealthState.starting,
    _ => HealthState.none,
  };

  /// `concurrency` workers pull the next item off a shared index; no
  /// external dependency needed for a small bounded worker pool.
  static Future<List<R>> _mapConcurrent<T, R>(
    List<T> items,
    int concurrency,
    Future<R> Function(T item) worker,
  ) async {
    final results = List<R?>.filled(items.length, null);
    var next = 0;
    Future<void> runWorker() async {
      while (next < items.length) {
        final i = next++;
        results[i] = await worker(items[i]);
      }
    }

    await Future.wait(
      List.generate(
        concurrency.clamp(1, items.length.clamp(1, concurrency)),
        (_) => runWorker(),
      ),
    );
    return results.cast<R>();
  }

  Future<dynamic> _getJson(String path) async {
    final body = await _get(path);
    try {
      return jsonDecode(body);
    } on FormatException catch (e) {
      throw ParseError(e.message);
    }
  }

  Future<String> _get(String path) async {
    final uri = Uri.parse('http://localhost/$apiVersion$path');

    final http.Response response;
    try {
      response = await client.get(uri).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const TimeoutError();
    } on SocketException catch (e) {
      throw NetworkError(e.osError?.message ?? e.message);
    } on HttpException catch (e) {
      throw NetworkError(e.message);
    } on http.ClientException catch (e) {
      throw NetworkError(e.message);
    } on TlsException catch (e) {
      throw NetworkError(e.message);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthError(response.statusCode, 'DOCKER');
    }
    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, 'DOCKER');
    }

    return response.body;
  }
}
