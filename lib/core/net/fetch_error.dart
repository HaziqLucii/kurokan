sealed class FetchError implements Exception {
  const FetchError();
}

class NetworkError extends FetchError {
  final String detail;
  const NetworkError(this.detail);
}

class AuthError extends FetchError {
  final int status;
  final String service;
  const AuthError(this.status, this.service);
}

class HttpError extends FetchError {
  final int status;
  final String service;
  const HttpError(this.status, this.service);
}

class ParseError extends FetchError {
  final String detail;
  const ParseError(this.detail);
}

class TimeoutError extends FetchError {
  const TimeoutError();
}
