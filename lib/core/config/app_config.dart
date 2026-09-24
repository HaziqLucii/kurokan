import 'config_schema.dart';

enum ThemePreference { system, dark, light }

ThemePreference themePreferenceFromString(String? value) {
  switch (value) {
    case 'dark':
      return ThemePreference.dark;
    case 'light':
      return ThemePreference.light;
    case null:
    case 'system':
      return ThemePreference.system;
    default:
      throw FormatException(
        'theme must be one of system, dark, light (got "$value")',
      );
  }
}

String themePreferenceToString(ThemePreference pref) => switch (pref) {
  ThemePreference.system => 'system',
  ThemePreference.dark => 'dark',
  ThemePreference.light => 'light',
};

class HistoryConfig {
  final Duration retention;

  const HistoryConfig({this.retention = const Duration(hours: 24)});

  factory HistoryConfig.fromJson(Map<String, dynamic>? json) {
    final hours = json?['retentionHours'];
    if (hours != null && hours is! int) {
      throw const FormatException('history.retentionHours must be an integer');
    }
    if (hours != null && hours < 0) {
      throw const FormatException(
        'history.retentionHours must not be negative',
      );
    }
    return HistoryConfig(retention: Duration(hours: hours ?? 24));
  }

  Map<String, dynamic> toJson() => {'retentionHours': retention.inHours};
}

class NotificationsConfig {
  final bool enabled;

  const NotificationsConfig({this.enabled = false});

  factory NotificationsConfig.fromJson(Map<String, dynamic>? json) {
    final enabled = json?['enabled'];
    if (enabled != null && enabled is! bool) {
      throw const FormatException('notifications.enabled must be a boolean');
    }
    return NotificationsConfig(enabled: enabled ?? false);
  }

  Map<String, dynamic> toJson() => {'enabled': enabled};
}

class LayoutConfig {
  final List<String> order;
  final bool incidents;

  const LayoutConfig({this.order = const [], this.incidents = true});

  factory LayoutConfig.fromJson(Map<String, dynamic>? json) {
    final orderRaw = json?['order'];
    if (orderRaw != null && orderRaw is! List) {
      throw const FormatException('layout.order must be a list');
    }
    final order = orderRaw == null
        ? const <String>[]
        : [for (final v in orderRaw) v.toString()];
    final incidents = json?['incidents'];
    if (incidents != null && incidents is! bool) {
      throw const FormatException('layout.incidents must be a boolean');
    }
    return LayoutConfig(order: order, incidents: incidents ?? true);
  }

  Map<String, dynamic> toJson() => {'order': order, 'incidents': incidents};
}

class AppConfig {
  static const schemaVersion = 2;
  static const defaultPollInterval = Duration(seconds: 30);

  final List<SourceEntry> hosts;
  final List<SourceEntry> uptime;
  final List<SourceEntry> containers;
  final Duration pollInterval;
  final ThemePreference theme;
  final HistoryConfig history;
  final NotificationsConfig notifications;
  final LayoutConfig layout;

  const AppConfig({
    this.hosts = const [],
    this.uptime = const [],
    this.containers = const [],
    this.pollInterval = defaultPollInterval,
    this.theme = ThemePreference.system,
    this.history = const HistoryConfig(),
    this.notifications = const NotificationsConfig(),
    this.layout = const LayoutConfig(),
  });

  /// The single configured host, if any. Temporary compatibility shim for
  /// the current single-source settings form and polling providers;
  /// deleted in Phase 3.1 once they handle N sources directly.
  SourceEntry? get firstHost => hosts.isEmpty ? null : hosts.first;

  /// The single configured uptime source, if any. Same caveat as [firstHost].
  SourceEntry? get firstUptime => uptime.isEmpty ? null : uptime.first;

  factory AppConfig.fromJson(
    Map<String, dynamic> json, {
    required ConfigSchema schema,
  }) {
    final version = json['version'];
    if (version != null && version != schemaVersion) {
      throw FormatException(
        'unsupported config version: $version (expected $schemaVersion)',
      );
    }

    final pollIntervalSec = json['pollIntervalSec'];
    if (pollIntervalSec != null && pollIntervalSec is! int) {
      throw const FormatException('pollIntervalSec must be an integer');
    }
    if (pollIntervalSec != null && pollIntervalSec <= 0) {
      throw const FormatException('pollIntervalSec must be a positive integer');
    }
    final themeValue = json['theme'];
    if (themeValue != null && themeValue is! String) {
      throw const FormatException(
        'theme must be a string (system, dark, or light)',
      );
    }

    final hosts = _parseEntries(
      json['hosts'],
      kind: SourceKind.host,
      listName: 'hosts',
      schema: schema,
    );
    final uptime = _parseEntries(
      json['uptime'],
      kind: SourceKind.uptime,
      listName: 'uptime',
      schema: schema,
    );
    final containers = _parseEntries(
      json['containers'],
      kind: SourceKind.containers,
      listName: 'containers',
      schema: schema,
    );

    final allIds = [...hosts, ...uptime, ...containers].map((e) => e.id);
    final seenIds = <String>{};
    for (final id in allIds) {
      if (!seenIds.add(id)) {
        throw FormatException('duplicate source id "$id"');
      }
    }
    if (seenIds.isEmpty) {
      throw const FormatException(
        'at least one source (hosts, uptime, or containers) is required',
      );
    }

    return AppConfig(
      hosts: hosts,
      uptime: uptime,
      containers: containers,
      pollInterval: Duration(
        seconds: pollIntervalSec ?? defaultPollInterval.inSeconds,
      ),
      theme: themePreferenceFromString(themeValue as String?),
      history: HistoryConfig.fromJson(json['history'] as Map<String, dynamic>?),
      notifications: NotificationsConfig.fromJson(
        json['notifications'] as Map<String, dynamic>?,
      ),
      layout: LayoutConfig.fromJson(json['layout'] as Map<String, dynamic>?),
    );
  }

  static List<SourceEntry> _parseEntries(
    dynamic raw, {
    required SourceKind kind,
    required String listName,
    required ConfigSchema schema,
  }) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw FormatException('$listName must be a list');
    }
    return [
      for (var i = 0; i < raw.length; i++)
        SourceEntry.fromJson(
          _asEntryObject(raw[i], listName: listName, index: i),
          kind: kind,
          listName: listName,
          index: i,
          schema: schema,
        ),
    ];
  }

  static Map<String, dynamic> _asEntryObject(
    dynamic raw, {
    required String listName,
    required int index,
  }) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException('$listName[$index] must be an object');
    }
    return raw;
  }

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'pollIntervalSec': pollInterval.inSeconds,
    'theme': themePreferenceToString(theme),
    'hosts': hosts.map((e) => e.toJson()).toList(),
    'uptime': uptime.map((e) => e.toJson()).toList(),
    'containers': containers.map((e) => e.toJson()).toList(),
    'history': history.toJson(),
    'notifications': notifications.toJson(),
    'layout': layout.toJson(),
  };
}

class ConfigError implements Exception {
  final String path;
  final String reason;
  final bool notFound;

  const ConfigError(this.path, this.reason, {this.notFound = false});

  @override
  String toString() => 'ConfigError($path: $reason)';
}
