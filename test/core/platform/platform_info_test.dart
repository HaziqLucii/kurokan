import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/platform/platform_info.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('isMacOS is true only when the target platform is macOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(PlatformInfo.isMacOS, isTrue);
    expect(PlatformInfo.isLinux, isFalse);
  });

  test('isLinux is true only when the target platform is linux', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(PlatformInfo.isLinux, isTrue);
    expect(PlatformInfo.isMacOS, isFalse);
  });
}
