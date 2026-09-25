import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/net/fetch_error.dart';
import '../domain/monitor_source.dart';
import '../domain/monitor_status.dart';
import 'prometheus_text_parser.dart';

class UptimeKumaMetricsSource implements MonitorSource {
  final Uri baseUrl;
  final String apiKey;
  final http.Client client;
  final PrometheusMetricsParser _parser;

  UptimeKumaMetricsSource({
    required String url,
    required this.apiKey,
    required this.client,
    PrometheusMetricsParser? parser,
  }) : baseUrl = Uri.parse(url),
       _parser = parser ?? PrometheusMetricsParser();

  @override
  Future<List<MonitorStatus>> fetch() async {
    final uri = baseUrl.resolve('/metrics');
    final basicAuth = 'Basic ${base64Encode(utf8.encode(':$apiKey'))}';

    final http.Response response;
    try {
      response = await client
          .get(uri, headers: {'Authorization': basicAuth})
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

    if (response.statusCode == 401) {
      throw AuthError(response.statusCode, 'KUMA');
    }
    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, 'KUMA');
    }

    try {
      return _parser.parse(response.body).monitors;
    } catch (e) {
      throw ParseError(e.toString());
    }
  }
}
