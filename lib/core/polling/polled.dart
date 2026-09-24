import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

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

/// Same as [polled], but keyed by an argument so N independent sources
/// (one per configured entry id) each get their own polling cycle.
/// Deliberately not autoDispose: an off-screen panel in a future
/// single-column layout must keep polling so history/events keep flowing,
/// and the ProviderScope re-key on config reload already disposes entries
/// that are removed. `ref.invalidate(family)` (the family itself, not a
/// keyed instance) refreshes every existing instance at once.
FutureProviderFamily<Sample<T>, A> polledFamily<T, A>(
  Duration Function(Ref ref, A arg) interval,
  Future<T> Function(Ref ref, A arg) fetch,
) {
  return FutureProvider.family<Sample<T>, A>((ref, arg) async {
    final timer = Timer(interval(ref, arg), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    final value = await fetch(ref, arg);
    return Sample(value, clock.now());
  }, retry: (_, _) => null);
}
