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
/// (matching the plan: no custom PromQL tiles, just this fixed set),
/// joined by `(job, instance)` — not `instance` alone, since two different
/// jobs can legitimately reuse the same instance label (confirmed against
/// a real deployment: an application-metrics job on the same box as a
/// node_exporter target). An empty result vector for one query degrades
/// just that gauge to null for the affected host(s), never the whole
/// fetch — a metric genuinely can be absent (a node_exporter build without
/// a given collector) without that meaning the host itself is unreachable.
///
/// Host discovery deliberately does NOT come from a plain `up` or
/// `node_uname_info` instant query. When a scrape target goes down,
/// Prometheus writes a stale marker for every series that target
/// previously exposed — except `up` itself, which Prometheus always
/// records (as 0) on every scrape attempt, successful or not. A plain
/// `node_uname_info` query would therefore make a down host vanish from
/// the dashboard entirely instead of showing as down, which is the
/// opposite of what a monitoring dashboard should do. Wrapping the name
/// query in `last_over_time(...[1h])` keeps a host's last-known name
/// queryable for up to an hour after it stops being scraped, long enough
/// for `up=0` to still join against it and render `status: 'error'`.
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
      _query(
        'last_over_time(${_sel('node_uname_info')}[1h])',
      ), // 0: (job,instance) -> nodename, survives a target going stale
      _query(_sel('up')), // 1: status + sampledAt
      _query(
        '100 * (1 - avg by(instance, job)(rate(${_sel('node_cpu_seconds_total', extra: 'mode="idle"')}[5m])))',
      ), // 2: cpu %
      _query(_sel('node_memory_MemTotal_bytes')), // 3: mem total
      _query(
        '${_sel('node_memory_MemTotal_bytes')} - ${_sel('node_memory_MemAvailable_bytes')}',
      ), // 4: mem used
      _query(_sel('node_filesystem_size_bytes', extra: _diskMatchers)), // 5
      _query(_sel('node_filesystem_avail_bytes', extra: _diskMatchers)), // 6
      _query(
        'sum by(instance, job)(increase(${_sel('node_network_receive_bytes_total', extra: _netMatchers)}[24h]))',
      ), // 7
      _query(
        'sum by(instance, job)(increase(${_sel('node_network_transmit_bytes_total', extra: _netMatchers)}[24h]))',
      ), // 8
      _query(_sel('node_load1')), // 9
      _query(_sel('node_load5')), // 10
      _query(_sel('node_load15')), // 11
      _query(
        '${_sel('node_time_seconds')} - ${_sel('node_boot_time_seconds')}',
      ), // 12: uptime seconds
      _query(_sel('node_procs_running')), // 13
    ]);

    final names = _byKey(raw[0]);
    final up = _byKey(raw[1]);
    final cpu = _byKey(raw[2]);
    final memTotal = _byKey(raw[3]);
    final memUsed = _byKey(raw[4]);
    final diskTotal = _byKey(raw[5]);
    final diskAvail = _byKey(raw[6]);
    final netRx = _byKey(raw[7]);
    final netTx = _byKey(raw[8]);
    final load1 = _byKey(raw[9]);
    final load5 = _byKey(raw[10]);
    final load15 = _byKey(raw[11]);
    final uptime = _byKey(raw[12]);
    final procs = _byKey(raw[13]);

    return names.entries.map((entry) {
      final key = entry.key;
      final instance = entry.value.metric['instance'] ?? key;
      final name = entry.value.metric['nodename'] ?? instance;

      final upSample = up[key];
      final status = (upSample != null && upSample.value >= 1)
          ? 'running'
          : 'error';
      final sampledAt = (upSample ?? entry.value).timestamp;

      final cpuPct = _finite(cpu[key]?.value);
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

      final mTotal = _finite(memTotal[key]?.value);
      final mUsed = _finite(memUsed[key]?.value);
      final memGauge = (mTotal == null || mUsed == null)
          ? null
          : Gauge.fromUsedAllowed(mUsed / _mib, mTotal / _mib, unit: 'MiB');

      final dTotal = _finite(diskTotal[key]?.value);
      final dAvail = _finite(diskAvail[key]?.value);
      final diskGauge = (dTotal == null || dAvail == null)
          ? null
          : Gauge.fromUsedAllowed(
              (dTotal - dAvail) / _mib,
              dTotal / _mib,
              unit: 'MiB',
              warnAt: 70,
              critAt: 90,
            );

      final rx = _finite(netRx[key]?.value);
      final tx = _finite(netTx[key]?.value);
      final netGauge = (rx == null || tx == null)
          ? null
          : Gauge.fromUsedAllowed(
              (rx + tx) / _gib,
              networkQuotaGiB,
              unit: 'GiB',
            );

      final l1 = _finite(load1[key]?.value);
      final l5 = _finite(load5[key]?.value);
      final l15 = _finite(load15[key]?.value);
      final uptimeSeconds = _finite(uptime[key]?.value);
      final extra = <String, String>{
        if (l1 != null) 'load1': l1.toStringAsFixed(2),
        if (l5 != null) 'load5': l5.toStringAsFixed(2),
        if (l15 != null) 'load15': l15.toStringAsFixed(2),
        if (uptimeSeconds != null)
          'uptimeSeconds': uptimeSeconds.round().toString(),
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
        processCount: _finite(procs[key]?.value)?.round(),
        sampledAt: sampledAt,
        extra: extra.isEmpty ? null : extra,
      );
    }).toList();
  }

  /// `NaN`/`Infinity` are valid PromQL sample values (a rate() over a
  /// counter reset, a `0/0` in some derived expression) that would
  /// otherwise reach `.round()` and throw `UnsupportedError` outside the
  /// `FetchError` hierarchy every other failure in this source goes
  /// through; treated the same as a missing sample instead.
  double? _finite(double? value) =>
      (value == null || !value.isFinite) ? null : value;

  /// Joins every query's result by `(job, instance)`, not `instance` alone:
  /// two different jobs can legitimately share an instance label (a
  /// node_exporter target and an unrelated application-metrics target on
  /// the same box), and collapsing them onto one key could silently mix up
  /// which job's `up`/gauges belong to which host.
  Map<String, PromSampleDTO> _byKey(List<PromSampleDTO> samples) {
    final map = <String, PromSampleDTO>{};
    for (final s in samples) {
      final instance = s.metric['instance'];
      if (instance == null) continue;
      map[_key(s.metric['job'], instance)] = s;
    }
    return map;
  }

  String _key(String? job, String instance) => '${job ?? ''}|$instance';

  /// Builds a PromQL selector, folding in the optional `job`/`instanceRegex`
  /// settings alongside any metric-specific matchers so every query — not
  /// just the plain ones — respects a scoped config entry. Both settings
  /// are escaped before being interpolated into a double-quoted PromQL
  /// string literal (Go-style escapes): unescaped, a regex containing an
  /// ordinary backslash escape like `10\..*` breaks every single query
  /// against a real server with a "bad_data: unknown escape sequence"
  /// error, which is exactly the kind of value this field exists to accept.
  String _sel(String metric, {String? extra}) {
    final matchers = <String>[
      ?extra,
      if (job != null) 'job="${_escapeLabelValue(job!)}"',
      if (instanceRegex != null)
        'instance=~"${_escapeLabelValue(instanceRegex!)}"',
    ];
    if (matchers.isEmpty) return metric;
    return '$metric{${matchers.join(',')}}';
  }

  String _escapeLabelValue(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

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
