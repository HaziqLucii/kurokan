import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// `flutter_test` doesn't load fonts declared in pubspec.yaml, so every
/// widget test renders text as Ahem boxes unless fonts are loaded by hand.
/// This runs once per test file (Flutter finds the nearest
/// flutter_test_config.dart up the directory tree and wraps that file's
/// main() with testExecutable), which is what the golden suite needs to
/// actually render Fraunces/Space Grotesk/Space Mono/Noto Serif JP.
Future<void> _loadAppFonts() async {
  final manifestContent = await rootBundle.loadString('FontManifest.json');
  final fontManifest = jsonDecode(manifestContent) as List<dynamic>;

  for (final dynamic entry in fontManifest) {
    final font = entry as Map<String, dynamic>;
    final family = font['family'] as String;
    final loader = FontLoader(family);
    final fonts = (font['fonts'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final asset in fonts) {
      // FontManifest.json percent-encodes special characters in the asset
      // path (e.g. Fraunces[SOFT,WONK,opsz,wght].ttf becomes ...%5BSOFT...),
      // but rootBundle.load() needs the raw, decoded key.
      final assetKey = Uri.decodeFull(asset['asset'] as String);
      loader.addFont(rootBundle.load(assetKey));
    }
    await loader.load();
  }
}

/// Accepts a golden match within [tolerance] percent pixel difference
/// instead of requiring byte-identical output. Real machines rasterize
/// text with tiny antialiasing/subpixel differences even on the same OS;
/// requiring an exact match makes goldens flake for reasons that have
/// nothing to do with an actual visual regression.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(Uri basedir) : super(basedir.resolve('_.dart'));

  // 0.1%: catches real regressions while tolerating rasterization noise.
  // Raise to 0.005 only if CI itself starts flaking at this threshold.
  static const double tolerance = 0.001;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadAppFonts();

  final existing = goldenFileComparator;
  if (existing is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(existing.basedir);
  }

  // Shadows rasterize slightly differently per machine; goldens don't need
  // to prove shadow rendering works, just layout and color.
  debugDisableShadows = true;

  await testMain();
}
