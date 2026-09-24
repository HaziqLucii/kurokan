enum FieldKind { text, url, secret, integer, path }

class FieldSpec {
  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final String? hint;

  const FieldSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.required = true,
    this.hint,
  });
}

abstract interface class ConfigSchema {
  List<FieldSpec>? hostFields(String provider);
  List<FieldSpec>? uptimeFields(String provider);
  List<FieldSpec>? containerFields(String provider);

  /// Every provider id [kind] recognizes, used only to name the allowed
  /// ids in an "unknown provider" error.
  List<String> providerIds(SourceKind kind);
}

enum SourceKind { host, uptime, containers }

class SourceEntry {
  final SourceKind kind;
  final String id;
  final String provider;
  final Map<String, String> settings;

  const SourceEntry({
    required this.kind,
    required this.id,
    required this.provider,
    required this.settings,
  });

  String get panelKey => '${kind.name}:$id';

  factory SourceEntry.fromJson(
    Map<String, dynamic> json, {
    required SourceKind kind,
    required String listName,
    required int index,
    required ConfigSchema schema,
  }) {
    final prefix = '$listName[$index]';
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$prefix.id is required');
    }
    final provider = json['provider'];
    if (provider is! String || provider.isEmpty) {
      throw FormatException('$prefix.provider is required');
    }

    final fields = switch (kind) {
      SourceKind.host => schema.hostFields(provider),
      SourceKind.uptime => schema.uptimeFields(provider),
      SourceKind.containers => schema.containerFields(provider),
    };
    if (fields == null) {
      final allowed = schema.providerIds(kind);
      final allowedText = allowed.isEmpty
          ? 'none configured for this build'
          : allowed.join(', ');
      throw FormatException(
        '$prefix has unknown provider "$provider" (known: $allowedText)',
      );
    }

    final settings = <String, String>{};
    for (final field in fields) {
      final value = json[field.key];
      if (value == null || (value is String && value.isEmpty)) {
        if (field.required) {
          throw FormatException('$prefix.${field.key} is required');
        }
        continue;
      }
      settings[field.key] = value.toString();
    }

    return SourceEntry(
      kind: kind,
      id: id,
      provider: provider,
      settings: settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    ...settings,
  };
}
