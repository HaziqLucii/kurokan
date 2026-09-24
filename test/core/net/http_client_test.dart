import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/net/http_client.dart';

void main() {
  test('createHttpClient returns a usable client', () {
    final client = createHttpClient();
    addTearDown(client.close);
    expect(client, isNotNull);
  });

  test('httpClientProvider builds a client and closes it on dispose', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(httpClientProvider), isNotNull);
  });
}
