import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/net/fetch_error.dart';
import '../domain/host_vitals.dart';
import '../domain/hosts_source.dart';
import 'prometheus_dto.dart';

/// Prometheus itself has no built-in auth; a bearer token only applies if
/// the endpoint sits behind a reverse proxy that checks one. `null` (no
/// [PromAuth] at all) sends no Authorization header, which is the common
/// case for a self-hosted instance reachable only over a private network.
class PromAuth {
  final String? bearerToken;
  const PromAuth({this.bearerToken});
}

/// A [HostsSource] over a Prometheus server scraping one or more
/// node_exporter targets — the first source that can yield more than one
/// host from a single config entry. One `GET /api/v1/query` per metric
/// (matching the plan: no custom PromQL tiles, just this fixed set), all
/// `by (instance)` so `instance` is the join key across every query. An
/// empty result vector for one query degrades just that gauge to null for
/// the affected host(s), never the whole fetch — a metric genuinely can be
/// absent (a node_exporter build without a given collector) without that
/// meaning the host itself is unreachable.
class PrometheusNodeSource implements HostsSource {
  static const _diskMatchers =
      'mountpoint="/",fstype!~"tmpfs|overlay|squashfs"';
  static const _netMatchers = 'device!~"lo|veth.*|docker.*|br-.*"';
  static const _mib = 1024 * 1024;
  static const _gib = 1024 * 1024 * 1024;

  final String url;
  final PromAuth? auth;
  final String? job;
  final String? instanceRegex;
  final double? networkQuotaGiB;
  final http.Client client;

  const PrometheusNodeSource({
    required this.url,
    this.auth,
    this.job,
    this.instanceRegex,
    this.networkQuotaGiB,
    required this.client,
  });

  @override
  Future<List<HostVitals>> fetch() async {
    final raw = await Future.wait([
      _query(_sel('node_uname_info')), // 0: instance -> nodename
      _query(_sel('up')), // 1: status + sampledAt
      _query(
        '100 * (1 - avg by(instance)(rate(${_sel('node_cpu_seconds_total', extra: 'mode="idle"')}[5m])))',
      ), // 2: cpu %
      _query(_sel('node_memory_MemTotal_bytes')), // 3: mem total
      _query(
        '${_sel('node_memory_MemTotal_bytes')} - ${_sel('node_memory_MemAvailable_bytes')}',
      ), // 4: mem used
      _query(_sel('node_filesystem_size_bytes', extra: _diskMatchers)), // 5
      _query(_sel('node_filesystem_avail_bytes', extra: _diskMatchers)), // 6
      _query(
        'sum by(instance)(increase(${_sel('node_network_receive_bytes_total', extra: _netMatchers)}[24h]))',
      ), // 7
      _query(
        'sum by(instance)(increase(${_sel('node_network_transmit_bytes_total', extra: _netMatchers)}[24h]))',
      ), // 8
      _query(_sel('node_load1')), // 9
      _query(_sel('node_load5')), // 10
      _query(_sel('node_load15')), // 11
      _query(
        '${_sel('node_time_seconds')} - ${_sel('node_boot_time_seconds')}',
      ), // 12: uptime seconds
      _query(_sel('node_procs_running')), // 13
    ]);

    final names = _byInstance(raw[0]);
    final up = _byInstance(raw[1]);
    final cpu = _byInstance(raw[2]);
    final memTotal = _byInstance(raw[3]);
    final memUsed = _byInstance(raw[4]);
    final diskTotal = _byInstance(raw[5]);
    final diskAvail = _byInstance(raw[6]);
    final netRx = _byInstance(raw[7]);
    final netTx = _byInstance(raw[8]);
    final load1 = _byInstance(raw[9]);
    final load5 = _byInstance(raw[10]);
    final load15 = _byInstance(raw[11]);
    final uptime = _byInstance(raw[12]);
    final procs = _byInstance(raw[13]);

    return names.entries.map((entry) {
      final instance = entry.key;
      final name = entry.value.metric['nodename'] ?? instance;

      final upSample = up[instance];
      final status = (upSample != null && upSample.value >= 1)
          ? 'running'
          : 'error';
      final sampledAt = (upSample ?? entry.value).timestamp;

      final cpuPct = cpu[instance]?.value;
      // Unlike memory/disk/network, HostVitals.cpu is non-nullable (every
      // other current provider always has one); a missing sample for a
      // real node_exporter target is not expected in practice (the metric
      // is as fundamental as node_uname_info itself), so this degrades to
      // an "unavailable" gauge rather than dropping the host.
      final cpuGauge = cpuPct == null
          ? const Gauge(
              used: 0,
              allowed: null,
              percentUsed: null,
              level: UsageLevel.ok,
              unit: '%',
            )
          : Gauge.fromUsedAllowed(cpuPct, 100, unit: '%');

      final mTotal = memTotal[instance]?.value;
      final mUsed = memUsed[instance]?.value;
      final memGauge = (mTotal == null || mUsed == null)
          ? null
          : Gauge.fromUsedAllowed(mUsed / _mib, mTotal / _mib, unit: 'MiB');

      final dTotal = diskTotal[instance]?.value;
      final dAvail = diskAvail[instance]?.value;
      final diskGauge = (dTotal == null || dAvail == null)
          ? null
          : Gauge.fromUsedAllowed(
              (dTotal - dAvail) / _mib,
              dTotal / _mib,
              unit: 'MiB',
              warnAt: 70,
              critAt: 90,
            );

      final rx = netRx[instance]?.value;
      final tx = netTx[instance]?.value;
      final netGauge = (rx == null || tx == null)
          ? null
          : Gauge.fromUsedAllowed(
              (rx + tx) / _gib,
              networkQuotaGiB,
              unit: 'GiB',
            );

      final extra = <String, String>{
        if (load1[instance] != null)
          'load1': load1[instance]!.value.toStringAsFixed(2),
        if (load5[instance] != null)
          'load5': load5[instance]!.value.toStringAsFixed(2),
        if (load15[instance] != null)
          'load15': load15[instance]!.value.toStringAsFixed(2),
        if (uptime[instance] != null)
          'uptimeSeconds': uptime[instance]!.value.round().toString(),
      };

      return HostVitals(
        slug: instance,
        name: name,
        status: status,
        ipv4: '',
        cpu: cpuGauge,
        memory: memGauge,
        disk: diskGauge,
        network: netGauge,
        processCount: procs[instance]?.value.round(),
        sampledAt: sampledAt,
        extra: extra.isEmpty ? null : extra,
      );
    }).toList();
  }

  Map<String, PromSampleDTO> _byInstance(List<PromSampleDTO> samples) {
    final map = <String, PromSampleDTO>{};
    for (final s in samples) {
      final instance = s.metric['instance'];
      if (instance != null) map[instance] = s;
    }
    return map;
  }

  /// Builds a PromQL selector, folding in the optional `job`/`instanceRegex`
  /// settings alongside any metric-specific matchers so every query — not
  /// just the plain ones — respects a scoped config entry.
  String _sel(String metric, {String? extra}) {
    final matchers = <String>[
      ?extra,
      if (job != null) 'job="$job"',
      if (instanceRegex != null) 'instance=~"$instanceRegex"',
    ];
    if (matchers.isEmpty) return metric;
    return '$metric{${matchers.join(',')}}';
  }

  Future<List<PromSampleDTO>> _query(String promql) async {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final uri = Uri.parse(
      '$base/api/v1/query',
    ).replace(queryParameters: {'query': promql});

    final headers = <String, String>{
      if (auth?.bearerToken != null)
        'Authorization': 'Bearer ${auth!.bearerToken}',
    };

    final http.Response response;
    try {
      response = await client
          .get(uri, headers: headers)
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
      throw AuthError(response.statusCode, 'PROMETHEUS');
    }
    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, 'PROMETHEUS');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw ParseError(e.message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ParseError('root must be a JSON object');
    }
    return parsePromVector(decoded);
  }
}
