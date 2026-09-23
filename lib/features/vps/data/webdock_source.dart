import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/net/fetch_error.dart';
import '../domain/host_vitals.dart';
import '../domain/vitals_source.dart';
import 'webdock_dto.dart';

class WebdockSource implements VitalsSource {
  static const _baseUrl = 'https://api.webdock.io/v1';

  final String slug;
  final String apiToken;
  final http.Client client;

  const WebdockSource({
    required this.slug,
    required this.apiToken,
    required this.client,
  });

  @override
  Future<HostVitals> fetch() async {
    final results = await Future.wait([
      _get('/servers/$slug'),
      _get('/servers/$slug/metrics/now'),
    ]);

    final ServerDTO server;
    final InstantServerMetricsDTO metrics;
    try {
      server = ServerDTO.fromJson(results[0]);
      metrics = InstantServerMetricsDTO.fromJson(results[1]);
    } catch (e) {
      throw ParseError(e.toString());
    }
    final status = metrics.resourceUsageStatus;

    return HostVitals(
      slug: server.slug,
      name: server.name,
      status: server.status,
      ipv4: server.ipv4 ?? '',
      // resourceUsageStatus.*.used/allowed are documented only as "the
      // metric's base unit" for all four resources (R1 in the plan). MiB/
      // GiB below follow the raw cpu/memory/disk/network metrics families,
      // which the spec documents explicitly elsewhere; CPU-seconds is the
      // least certain of the four and is the one pending a real sample.
      cpu: _gauge(status.cpu, unit: 'CPU-s'),
      memory: _gauge(status.memory, unit: 'MiB'),
      disk: _gauge(status.disk, unit: 'MiB'),
      network: _gauge(status.network, unit: 'GiB'),
      processCount: metrics.processCount,
      sampledAt: metrics.memorySampledAt,
    );
  }

  Gauge _gauge(ResourceUsageMetricStatusDTO dto, {required String unit}) =>
      Gauge(
        used: dto.used,
        allowed: dto.allowed,
        percentUsed: dto.percentUsed,
        level: _levelFromString(dto.level),
        unit: unit,
      );

  UsageLevel _levelFromString(String level) => switch (level) {
    'warn' => UsageLevel.warn,
    'crit' => UsageLevel.crit,
    _ => UsageLevel.ok,
  };

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');

    final http.Response response;
    try {
      response = await client
          .get(uri, headers: {'Authorization': 'Bearer $apiToken'})
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const TimeoutError();
    } on SocketException catch (e) {
      throw NetworkError(
        '${e.osError?.message ?? e.message} ${uri.host}:${uri.port}',
      );
    } on HttpException catch (e) {
      throw NetworkError('${e.message} ${uri.host}:${uri.port}');
    } on http.ClientException catch (e) {
      throw NetworkError('${e.message} ${uri.host}:${uri.port}');
    } on TlsException catch (e) {
      throw NetworkError('${e.message} ${uri.host}:${uri.port}');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      // 403 means the token is valid but lacks the read:servers permission
      // scope — surfacing it the same as 401 points at the same fix
      // (webdock.apiToken) rather than reading as an opaque HTTP error.
      throw AuthError(response.statusCode, 'WEBDOCK');
    }
    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, 'WEBDOCK');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('root must be a JSON object');
      }
      return decoded;
    } on FormatException catch (e) {
      throw ParseError(e.message);
    }
  }
}
