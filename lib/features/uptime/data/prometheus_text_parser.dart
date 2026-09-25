import '../domain/monitor_status.dart';

/// [hasIds]: whether any monitor line carried a `monitor_id` label (older
/// Kuma versions, e.g. 1.23.x, don't emit one). [hasUptime]: whether any
/// `monitor_uptime_ratio` line was present at all, for any window — some
/// Kuma versions don't emit uptime ratios, so the 24H column can show `—`
/// because the data genuinely isn't there, not because of a parsing gap.
class ParseResult {
  final List<MonitorStatus> monitors;
  final bool hasIds;
  final bool hasUptime;

  const ParseResult({
    required this.monitors,
    required this.hasIds,
    required this.hasUptime,
  });
}

class _Accumulator {
  String name;
  String type;
  MonitorState? state;
  Duration? responseTime;
  double? uptime24h;
  int? certDaysRemaining;
  bool? certValid;
  Map<String, String>? extra;

  _Accumulator({required this.name, required this.type});
}

class PrometheusMetricsParser {
  static const _monitorPrefix = 'monitor_';

  static final _lineRegex = RegExp(
    r'^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{(.*)\})?\s+(\S+)$',
  );
  static final _labelRegex = RegExp(
    r'([a-zA-Z_][a-zA-Z0-9_]*)="((?:[^"\\]|\\.)*)"',
  );

  ParseResult parse(String body) {
    final byKey = <String, _Accumulator>{};
    final order = <String>[];
    var matchedAnyLine = false;
    var hasIds = false;
    var hasUptime = false;

    for (final rawLine in body.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty || line.startsWith('#')) continue;

      final match = _lineRegex.firstMatch(line);
      if (match == null) continue;
      matchedAnyLine = true;

      final metric = match.group(1)!;
      if (!metric.startsWith(_monitorPrefix)) continue;

      final labels = _parseLabels(match.group(3) ?? '');
      final name = labels['monitor_name'];
      if (name == null) continue;

      final monitorId = labels['monitor_id'];
      if (monitorId != null) hasIds = true;

      // Kuma allows duplicate display names; without a monitor_id, series
      // identity falls back to the full label set (name/type/url/hostname/
      // port). Tag labels are deliberately excluded from both: two monitors
      // that differ only by tag are still the same monitor.
      final compositeKey = [
        name,
        labels['monitor_type'] ?? '',
        labels['monitor_url'] ?? '',
        labels['monitor_hostname'] ?? '',
        labels['monitor_port'] ?? '',
      ].join('|');
      final key = monitorId ?? compositeKey;

      final acc = byKey.putIfAbsent(key, () {
        order.add(key);
        return _Accumulator(name: name, type: labels['monitor_type'] ?? '');
      });

      // monitor_status is authoritative for identity: right after a rename,
      // a stale ("orphan") series sharing the same id can briefly still be
      // scraped alongside the live one until Prometheus's cache catches up.
      // Whichever series carries monitor_status wins the display name/type.
      if (metric == 'monitor_status') {
        acc.name = name;
        acc.type = labels['monitor_type'] ?? acc.type;
      }

      final value = double.tryParse(match.group(4)!);
      // double.tryParse('NaN') succeeds in Dart (returns double.nan), so
      // this needs its own explicit guard, not just a null check.
      if (value == null || value.isNaN) continue;

      switch (metric) {
        case 'monitor_status':
          acc.state = _stateFromCode(value);
        case 'monitor_response_time':
          acc.responseTime = value < 0
              ? null
              : Duration(milliseconds: value.round());
        case 'monitor_uptime_ratio':
          hasUptime = true;
          final window = labels['window'];
          if (window == '1d') {
            acc.uptime24h = value;
          } else if (window == '30d' || window == '365d') {
            (acc.extra ??= {})['uptime_$window'] = value.toString();
          }
        case 'monitor_cert_days_remaining':
          acc.certDaysRemaining = value.round();
        case 'monitor_cert_is_valid':
          acc.certValid = value != 0;
        // monitor_response_time_seconds and any other monitor_* metric not
        // listed above (e.g. a future addition) is deliberately ignored:
        // monitor_response_time (ms) is the one this app displays.
      }
    }

    if (!matchedAnyLine) {
      throw const FormatException(
        'no Prometheus metrics found in response body',
      );
    }

    return ParseResult(
      monitors: [
        for (final key in order)
          MonitorStatus(
            id: key,
            name: byKey[key]!.name,
            type: byKey[key]!.type,
            state: byKey[key]!.state ?? MonitorState.pending,
            responseTime: byKey[key]!.responseTime,
            uptime24h: byKey[key]!.uptime24h,
            certDaysRemaining: byKey[key]!.certDaysRemaining,
            certValid: byKey[key]!.certValid,
            extra: byKey[key]!.extra,
          ),
      ],
      hasIds: hasIds,
      hasUptime: hasUptime,
    );
  }

  Map<String, String?> _parseLabels(String raw) {
    final result = <String, String?>{};
    for (final m in _labelRegex.allMatches(raw)) {
      final key = m.group(1)!;
      final value = _unescape(m.group(2)!);
      result[key] = (value.isEmpty || value == 'null') ? null : value;
    }
    return result;
  }

  String _unescape(String s) {
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length) {
        final next = s[i + 1];
        switch (next) {
          case '"':
            buffer.write('"');
            i++;
          case 'n':
            buffer.write('\n');
            i++;
          case r'\':
            buffer.write(r'\');
            i++;
          default:
            buffer.write(c);
        }
      } else {
        buffer.write(c);
      }
    }
    return buffer.toString();
  }

  MonitorState _stateFromCode(double value) {
    switch (value.round()) {
      case 1:
        return MonitorState.up;
      case 0:
        return MonitorState.down;
      case 3:
        return MonitorState.maintenance;
      case 2:
      default:
        return MonitorState.pending;
    }
  }
}
