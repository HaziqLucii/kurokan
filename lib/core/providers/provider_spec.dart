import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../config/config_schema.dart';

class SourceDeps {
  final http.Client client;
  final Clock clock;

  const SourceDeps({required this.client, required this.clock});
}

class ProviderSpec<S> {
  final String id;
  final String tag;
  final SourceKind kind;
  final List<FieldSpec> fields;
  final S Function(SourceEntry entry, SourceDeps deps) create;
  final String Function(SourceEntry entry) label;

  const ProviderSpec({
    required this.id,
    required this.tag,
    required this.kind,
    required this.fields,
    required this.create,
    required this.label,
  });
}
