import '../domain/monitor_status.dart';

class _Accumulator {
  final String name;
  String type;
  MonitorState? state;
  Duration? responseTime;
  double? uptime24h;
  int? certDaysRemaining;
  bool? certValid;

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

  List<MonitorStatus> parse(String body) {
    final byKey = <String, _Accumulator>{};
    final order = <String>[];
    var matchedAnyLine = false;

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

      // Kuma allows duplicate display names; the series identity is the full
      // label set (name/type/url/hostname/port), not the name alone.
      final key = [
        name,
        labels['monitor_type'] ?? '',
        labels['monitor_url'] ?? '',
        labels['monitor_hostname'] ?? '',
        labels['monitor_port'] ?? '',
      ].join('|');

      final acc = byKey.putIfAbsent(key, () {
        order.add(key);
        return _Accumulator(name: name, type: labels['monitor_type'] ?? '');
      });

      final value = double.tryParse(match.group(4)!);
      if (value == null) continue;

      switch (metric) {
        case 'monitor_status':
          acc.state = _stateFromCode(value);
        case 'monitor_response_time':
          acc.responseTime = value < 0
              ? null
              : Duration(milliseconds: value.round());
        case 'monitor_uptime_ratio':
          if (labels['window'] == '1d') acc.uptime24h = value;
        case 'monitor_cert_days_remaining':
          acc.certDaysRemaining = value.round();
        case 'monitor_cert_is_valid':
          acc.certValid = value != 0;
      }
    }

    if (!matchedAnyLine) {
      throw const FormatException(
        'no Prometheus metrics found in response body',
      );
    }

    return [
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
        ),
    ];
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
