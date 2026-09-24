import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/net/fetch_error.dart';
import 'package:kurokan/shared/widgets/source_error_text.dart';

void main() {
  group('sourceErrorKind', () {
    test('maps every FetchError subtype to its short kind', () {
      expect(sourceErrorKind(const NetworkError('refused')), 'NETWORK');
      expect(sourceErrorKind(const AuthError(401, 'x')), 'AUTH');
      expect(sourceErrorKind(const HttpError(500, 'x')), 'HTTP');
      expect(sourceErrorKind(const ParseError('bad json')), 'PARSE');
      expect(sourceErrorKind(const TimeoutError()), 'TIMEOUT');
    });

    test('falls back to ERROR for anything else', () {
      expect(sourceErrorKind(Exception('boom')), 'ERROR');
      expect(sourceErrorKind(null), 'ERROR');
    });
  });

  group('sourceErrorMessage', () {
    test(
      'names the passed-in tag, not the FetchError\'s own service field',
      () {
        // AuthError/HttpError carry their own `service`, but the message uses
        // the caller's `tag` instead: the same FetchError can surface from
        // different providers depending on which panel's source threw it.
        expect(
          sourceErrorMessage(
            const NetworkError('connection refused'),
            tag: 'WEBDOCK',
          ),
          'NETWORK · connection refused · CHECK WEBDOCK CONNECTIVITY',
        );
        expect(
          sourceErrorMessage(const AuthError(401, 'ignored'), tag: 'KUMA'),
          'AUTH · 401 FROM KUMA · CHECK CREDENTIALS',
        );
        expect(
          sourceErrorMessage(const HttpError(503, 'ignored'), tag: 'KUMA'),
          'HTTP · 503 FROM KUMA',
        );
        expect(
          sourceErrorMessage(const ParseError('unexpected token'), tag: 'X'),
          'PARSE · unexpected token',
        );
        expect(
          sourceErrorMessage(const TimeoutError(), tag: 'X'),
          'TIMEOUT · 10S',
        );
      },
    );

    test('falls back to a generic message for anything else', () {
      expect(sourceErrorMessage(Exception('boom'), tag: 'X'), 'UNKNOWN ERROR');
    });
  });
}
