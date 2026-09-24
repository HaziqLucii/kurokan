import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'http_client_web.dart'
    if (dart.library.io) 'http_client_io.dart'
    as impl;

http.Client createHttpClient() => impl.createHttpClient();

final httpClientProvider = Provider<http.Client>((ref) {
  final client = createHttpClient();
  ref.onDispose(client.close);
  return client;
});
