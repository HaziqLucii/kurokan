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

class WebdockConfig {
  final String slug;
  final String apiToken;

  const WebdockConfig({required this.slug, required this.apiToken});

  factory WebdockConfig.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'];
    final apiToken = json['apiToken'];
    if (slug is! String || slug.isEmpty) {
      throw const FormatException('webdock.slug is required');
    }
    if (apiToken is! String || apiToken.isEmpty) {
      throw const FormatException('webdock.apiToken is required');
    }
    return WebdockConfig(slug: slug, apiToken: apiToken);
  }

  Map<String, dynamic> toJson() => {'slug': slug, 'apiToken': apiToken};
}

class KumaConfig {
  final String url;
  final String apiKey;

  const KumaConfig({required this.url, required this.apiKey});

  factory KumaConfig.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final apiKey = json['apiKey'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('kuma.url is required');
    }
    if (apiKey is! String || apiKey.isEmpty) {
      throw const FormatException('kuma.apiKey is required');
    }
    return KumaConfig(url: url, apiKey: apiKey);
  }

  Map<String, dynamic> toJson() => {'url': url, 'apiKey': apiKey};
}

class AppConfig {
  final WebdockConfig webdock;
  final KumaConfig kuma;
  final Duration pollInterval;
  final ThemePreference theme;

  static const defaultPollInterval = Duration(seconds: 30);

  const AppConfig({
    required this.webdock,
    required this.kuma,
    this.pollInterval = defaultPollInterval,
    this.theme = ThemePreference.system,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final webdockJson = json['webdock'];
    final kumaJson = json['kuma'];
    if (webdockJson is! Map<String, dynamic>) {
      throw const FormatException('webdock section is required');
    }
    if (kumaJson is! Map<String, dynamic>) {
      throw const FormatException('kuma section is required');
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
    return AppConfig(
      webdock: WebdockConfig.fromJson(webdockJson),
      kuma: KumaConfig.fromJson(kumaJson),
      pollInterval: Duration(
        seconds: pollIntervalSec ?? defaultPollInterval.inSeconds,
      ),
      theme: themePreferenceFromString(themeValue as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'webdock': webdock.toJson(),
    'kuma': kuma.toJson(),
    'pollIntervalSec': pollInterval.inSeconds,
    'theme': themePreferenceToString(theme),
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
