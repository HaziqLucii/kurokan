import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/config/app_config.dart';
import 'package:kurokan/core/providers/default_registry.dart';
import 'package:kurokan/features/demo/demo_config.dart';

void main() {
  test('demoConfig() has one demo host and one demo uptime entry', () {
    final config = demoConfig();
    expect(config.hosts, hasLength(1));
    expect(config.hosts.single.provider, 'demo');
    expect(config.uptime, hasLength(1));
    expect(config.uptime.single.provider, 'demo');
  });

  test('demoConfig() round-trips through the real validation pipeline', () {
    final config = demoConfig();
    final json = config.toJson();

    // Proves demoConfig() is exactly as loadable as any file a user writes
    // by hand: same AppConfig.fromJson call, same defaultRegistry schema.
    final reloaded = AppConfig.fromJson(json, schema: defaultRegistry);

    expect(reloaded.hosts.single.provider, 'demo');
    expect(reloaded.uptime.single.provider, 'demo');
  });
}
