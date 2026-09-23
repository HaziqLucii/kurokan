import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sample.dart';

FutureProvider<Sample<T>> polled<T>(
  Duration Function(Ref ref) interval,
  Future<T> Function(Ref ref) fetch,
) {
  return FutureProvider<Sample<T>>((ref) async {
    final timer = Timer(interval(ref), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    final value = await fetch(ref);
    return Sample(value, clock.now());
  }, retry: (_, _) => null);
}
