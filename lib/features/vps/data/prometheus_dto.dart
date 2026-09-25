import '../../../core/net/fetch_error.dart';

/// One time series from a Prometheus instant-vector query result: its
/// labels (`metric`), the sample's value, and the timestamp Prometheus
/// evaluated it at (its own clock, not ours — more accurate than stamping
/// every host with "now" from this machine).
class PromSampleDTO {
  final Map<String, String> metric;
  final double value;
  final DateTime timestamp;

  const PromSampleDTO({
    required this.metric,
    required this.value,
    required this.timestamp,
  });

  factory PromSampleDTO.fromJson(Map<String, dynamic> json) {
    final rawMetric = json['metric'] as Map<String, dynamic>? ?? const {};
    final valueArr = json['value'] as List<dynamic>;
    final epochSeconds = (valueArr[0] as num).toDouble();
    return PromSampleDTO(
      metric: rawMetric.map((k, v) => MapEntry(k, v.toString())),
      value: _parseSampleValue(valueArr[1] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (epochSeconds * 1000).round(),
        isUtc: true,
      ).toLocal(),
    );
  }
}

/// Prometheus writes `NaN`/`+Inf`/`-Inf` as valid sample values (e.g. a
/// `rate()` across a counter reset). Dart's `double.parse` understands
/// `NaN`/`Infinity`/`-Infinity` but not Prometheus's abbreviated `+Inf`/
/// `-Inf`, so those two would otherwise throw a raw `FormatException` that
/// escapes past every other error path in this source going through
/// [ParseError].
double _parseSampleValue(String raw) {
  final normalized = switch (raw) {
    '+Inf' => 'Infinity',
    '-Inf' => '-Infinity',
    _ => raw,
  };
  try {
    return double.parse(normalized);
  } on FormatException {
    throw ParseError('unparseable sample value "$raw"');
  }
}

/// Parses a Prometheus `/api/v1/query` response, expecting an instant
/// vector. Prometheus reports a query error inside a 200 response body
/// (`status: "error"`), not just via HTTP status, so that's checked here
/// rather than left to look like an empty result.
List<PromSampleDTO> parsePromVector(Map<String, dynamic> json) {
  if (json['status'] != 'success') {
    throw ParseError(json['error']?.toString() ?? 'query failed');
  }
  final data = json['data'];
  if (data is! Map<String, dynamic> || data['resultType'] != 'vector') {
    throw ParseError('expected an instant vector result');
  }
  final result = data['result'];
  if (result is! List) {
    throw const ParseError('result is not a JSON array');
  }
  return result
      .cast<Map<String, dynamic>>()
      .map(PromSampleDTO.fromJson)
      .toList();
}
