import '../../core/net/fetch_error.dart';

/// Short, provider-agnostic error kind used in a panel's "stale" footer
/// (e.g. "Stale · Last ok 12:00:00 · NETWORK").
String sourceErrorKind(Object? error) => switch (error) {
  NetworkError _ => 'NETWORK',
  AuthError _ => 'AUTH',
  HttpError _ => 'HTTP',
  ParseError _ => 'PARSE',
  TimeoutError _ => 'TIMEOUT',
  _ => 'ERROR',
};

/// Full error message shown in a panel's error body. Deliberately doesn't
/// name a specific settings field (the pre-N-source panels used to say
/// "CHECK webdock.slug" / "CHECK kuma.apiKey"): with N possible providers
/// per panel, a hardcoded field name would be wrong for every provider but
/// one. [tag] is the active provider's display tag (e.g. "WEBDOCK", "DEMO").
String sourceErrorMessage(Object? error, {required String tag}) =>
    switch (error) {
      NetworkError e => 'NETWORK · ${e.detail} · CHECK $tag CONNECTIVITY',
      AuthError e => 'AUTH · ${e.status} FROM $tag · CHECK CREDENTIALS',
      HttpError e => 'HTTP · ${e.status} FROM $tag',
      ParseError e => 'PARSE · ${e.detail}',
      TimeoutError _ => 'TIMEOUT · 10S',
      _ => 'UNKNOWN ERROR',
    };
