import 'dart:io';

import '../../../core/net/docker_client_io.dart';

const _fallbackSocketPath = '/var/run/docker.sock';

/// Resolves the `endpoint` settings field (default `'auto'`) to a concrete
/// [DockerEndpoint]. A non-`'auto'` value is parsed the same way `DOCKER_HOST`
/// is: `unix:///path`, `tcp://host:port`, or a bare path treated as a unix
/// socket.
///
/// [exists] defaults to a real filesystem check; tests inject a fake so the
/// "which candidate socket exists" search is deterministic regardless of
/// what's actually on the machine running the test.
DockerEndpoint resolveDockerEndpoint(
  String setting, {
  required Map<String, String> env,
  bool Function(String path) exists = _fileExists,
}) {
  if (setting.isNotEmpty && setting != 'auto') {
    return _parseDockerHost(setting);
  }

  final dockerHost = env['DOCKER_HOST'];
  if (dockerHost != null && dockerHost.isNotEmpty) {
    return _parseDockerHost(dockerHost);
  }

  final home = env['HOME'];
  final xdgRuntimeDir = env['XDG_RUNTIME_DIR'];
  final uid = env['UID'];
  final candidates = [
    _fallbackSocketPath,
    if (xdgRuntimeDir != null && xdgRuntimeDir.isNotEmpty)
      '$xdgRuntimeDir/docker.sock',
    if (home != null) '$home/.docker/run/docker.sock',
    if (home != null) '$home/.orbstack/run/docker.sock',
    if (home != null) '$home/.colima/default/docker.sock',
    // $XDG_RUNTIME_DIR/podman/podman.sock first: rootless Podman actually
    // sets XDG_RUNTIME_DIR (systemd user sessions export it by default),
    // whereas $UID is a shell-builtin variable most shells never export to
    // the environment at all, and a GUI-launched app has no shell to
    // inherit it from either way — this candidate is effectively dead in
    // practice, kept only for a shell session that happens to export it.
    if (xdgRuntimeDir != null && xdgRuntimeDir.isNotEmpty)
      '$xdgRuntimeDir/podman/podman.sock',
    if (uid != null && uid.isNotEmpty) '/run/user/$uid/podman/podman.sock',
  ];
  for (final path in candidates) {
    if (exists(path)) return UnixSocket(path);
  }

  // Nothing found: fall back to the most common path anyway, so the error
  // the user sees is a clear "connection refused at /var/run/docker.sock",
  // not a confusing "no endpoint configured".
  return const UnixSocket(_fallbackSocketPath);
}

bool _fileExists(String path) => File(path).existsSync();

DockerEndpoint _parseDockerHost(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return UnixSocket(value);
  switch (uri.scheme) {
    case 'unix':
      return UnixSocket(uri.path);
    case 'tcp':
    case 'http':
    case 'https':
      return Tcp(uri.host, uri.hasPort ? uri.port : 2375);
    default:
      return UnixSocket(value);
  }
}
