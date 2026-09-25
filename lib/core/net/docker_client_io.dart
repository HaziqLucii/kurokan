import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Where to reach a Docker/Podman-compatible engine's API.
sealed class DockerEndpoint {
  const DockerEndpoint();
}

class UnixSocket extends DockerEndpoint {
  final String path;
  const UnixSocket(this.path);
}

class Tcp extends DockerEndpoint {
  final String host;
  final int port;

  /// Accepted but not yet used: TLS via `DOCKER_CERT_PATH`/`SecurityContext`
  /// is a documented follow-up, not implemented here (see docs/DECISIONS.md).
  final String? certPath;
  const Tcp(this.host, this.port, {this.certPath});
}

/// Builds an [http.Client] that reaches [endpoint], redirecting every
/// connection to it regardless of the request URI's own host/port —
/// `DockerSource` (per the plan's own constructor, which takes no endpoint)
/// always addresses requests to a placeholder host, and this is what makes
/// that work for both a unix socket and a TCP daemon alike.
http.Client dockerHttpClient(DockerEndpoint endpoint) {
  final io = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  switch (endpoint) {
    case UnixSocket(:final path):
      io.connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
    case Tcp(:final host, :final port):
      io.connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(host, port);
  }
  // Proxies aren't meaningful for either transport; without this, some
  // environments (a system HTTP_PROXY) could otherwise interfere.
  io.findProxy = (uri) => 'DIRECT';
  return IOClient(io);
}
