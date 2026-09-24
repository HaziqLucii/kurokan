import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/core/polling/polled.dart';

void main() {
  test(
    'fetches again after one interval and stamps fetchedAt from the clock',
    () {
      fakeAsync((async) {
        final fakeClock = async.getClock(DateTime(2026, 1, 1));
        withClock(fakeClock, () {
          var callCount = 0;
          final provider = polled<int>((ref) => const Duration(seconds: 30), (
            ref,
          ) async {
            callCount++;
            return callCount;
          });

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final sub = container.listen(provider, (prev, next) {});

          async.elapse(Duration.zero);
          expect(callCount, 1);
          expect(container.read(provider).value?.value, 1);
          expect(container.read(provider).value?.fetchedAt, fakeClock.now());

          async.elapse(const Duration(seconds: 30));
          expect(callCount, 2);
          expect(container.read(provider).value?.value, 2);
          expect(container.read(provider).value?.fetchedAt, fakeClock.now());

          sub.close();
        });
      });
    },
  );

  test(
    'an error after a value keeps hasValue true (stale, not error-only)',
    () {
      fakeAsync((async) {
        final fakeClock = async.getClock(DateTime(2026, 1, 1));
        withClock(fakeClock, () {
          var callCount = 0;
          final provider = polled<int>((ref) => const Duration(seconds: 30), (
            ref,
          ) async {
            callCount++;
            if (callCount == 2) throw Exception('fetch failed');
            return callCount;
          });

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final sub = container.listen(provider, (prev, next) {});

          async.elapse(Duration.zero);
          expect(container.read(provider).hasValue, isTrue);
          expect(container.read(provider).value?.value, 1);

          async.elapse(const Duration(seconds: 30));
          final state = container.read(provider);
          expect(state.hasError, isTrue);
          expect(state.hasValue, isTrue);
          expect(state.value?.value, 1);

          sub.close();
        });
      });
    },
  );

  test(
    'does not retry automatically on error (the Timer alone owns cadence)',
    () {
      fakeAsync((async) {
        withClock(async.getClock(DateTime(2026, 1, 1)), () {
          var callCount = 0;
          final provider = polled<int>((ref) => const Duration(seconds: 30), (
            ref,
          ) async {
            callCount++;
            throw Exception('always fails');
          });

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final sub = container.listen(provider, (prev, next) {});

          async.elapse(Duration.zero);
          expect(callCount, 1);

          // Without retry: off, a longer elapse with no further interval ticks
          // should not produce additional fetch attempts.
          async.elapse(const Duration(seconds: 29));
          expect(callCount, 1);

          async.elapse(const Duration(seconds: 1));
          expect(callCount, 2);

          sub.close();
        });
      });
    },
  );

  group('polledFamily', () {
    test('each arg gets its own independent fetch and interval', () {
      fakeAsync((async) {
        final fakeClock = async.getClock(DateTime(2026, 1, 1));
        withClock(fakeClock, () {
          final callCounts = <String, int>{};
          final family = polledFamily<int, String>(
            (ref, arg) => const Duration(seconds: 30),
            (ref, arg) async {
              callCounts[arg] = (callCounts[arg] ?? 0) + 1;
              return callCounts[arg]!;
            },
          );

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final subA = container.listen(family('a'), (prev, next) {});
          final subB = container.listen(family('b'), (prev, next) {});

          async.elapse(Duration.zero);
          expect(container.read(family('a')).value?.value, 1);
          expect(container.read(family('b')).value?.value, 1);

          async.elapse(const Duration(seconds: 30));
          expect(container.read(family('a')).value?.value, 2);
          expect(container.read(family('b')).value?.value, 2);

          subA.close();
          subB.close();
        });
      });
    });

    test('invalidating the family refreshes every existing instance', () {
      fakeAsync((async) {
        withClock(async.getClock(DateTime(2026, 1, 1)), () {
          final callCounts = <String, int>{};
          final family = polledFamily<int, String>(
            (ref, arg) => const Duration(seconds: 30),
            (ref, arg) async {
              callCounts[arg] = (callCounts[arg] ?? 0) + 1;
              return callCounts[arg]!;
            },
          );

          final container = ProviderContainer();
          addTearDown(container.dispose);
          final subA = container.listen(family('a'), (prev, next) {});
          final subB = container.listen(family('b'), (prev, next) {});

          async.elapse(Duration.zero);
          expect(callCounts['a'], 1);
          expect(callCounts['b'], 1);

          container.invalidate(family);
          async.elapse(Duration.zero);
          expect(callCounts['a'], 2);
          expect(callCounts['b'], 2);

          subA.close();
          subB.close();
        });
      });
    });
  });
}
