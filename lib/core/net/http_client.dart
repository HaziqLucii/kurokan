import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../version.dart';

class _UserAgentClient extends http.BaseClient {
  final http.Client _inner;
  _UserAgentClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = 'kurokan/$appVersion';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

http.Client createHttpClient() {
  final io = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  return _UserAgentClient(IOClient(io));
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = createHttpClient();
  ref.onDispose(client.close);
  return client;
});
