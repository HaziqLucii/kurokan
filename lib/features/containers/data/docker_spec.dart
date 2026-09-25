import 'dart:io';

import '../../../core/config/config_schema.dart';
import '../../../core/net/docker_client_io.dart';
import '../../../core/providers/provider_spec.dart';
import '../domain/container_status.dart';
import 'docker_endpoint_discovery.dart';
import 'docker_source.dart';

const dockerSpec = ProviderSpec<ContainerSource>(
  id: 'docker',
  tag: 'DOCKER',
  kind: SourceKind.containers,
  fields: [
    FieldSpec(
      key: 'endpoint',
      label: 'Endpoint',
      kind: FieldKind.text,
      required: false,
      hint: 'auto, a unix socket path, or tcp://host:port',
    ),
  ],
  create: _create,
  label: _label,
);

ContainerSource _create(SourceEntry entry, SourceDeps deps) {
  final endpoint = resolveDockerEndpoint(
    entry.settings['endpoint'] ?? 'auto',
    env: Platform.environment,
  );
  return DockerSource(client: dockerHttpClient(endpoint));
}

String _label(SourceEntry entry) {
  final endpoint = entry.settings['endpoint'];
  return (endpoint == null || endpoint.isEmpty || endpoint == 'auto')
      ? 'Docker'
      : endpoint;
}
