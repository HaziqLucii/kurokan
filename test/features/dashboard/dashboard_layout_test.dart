import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/dashboard/dashboard_layout.dart';
import 'package:kurokan/features/dashboard/panel_registry.dart';

PanelEntry _panel(String key, PanelSlot slot) => PanelEntry(
  key: key,
  sourceId: key,
  slot: slot,
  fetchedAt: null,
  isLoading: false,
  hasError: false,
  build: () => const SizedBox(),
);

void main() {
  final uptime = _panel('uptime:kuma', PanelSlot.wide);
  final host = _panel('host:webdock', PanelSlot.narrow);
  final panels = [uptime, host];

  test(
    'at or above the breakpoint, splits panels into wide/narrow columns',
    () {
      final plan = planLayout(panels, dashboardLayoutBreakpoint);

      expect(plan, isA<TwoColumn>());
      final twoColumn = plan as TwoColumn;
      expect(twoColumn.wide, [uptime]);
      expect(twoColumn.narrow, [host]);
    },
  );

  test('above the breakpoint, still splits into wide/narrow columns', () {
    final plan = planLayout(panels, dashboardLayoutBreakpoint + 400);

    expect(plan, isA<TwoColumn>());
  });

  test('below the breakpoint, stacks every panel into a single column', () {
    final plan = planLayout(panels, dashboardLayoutBreakpoint - 1);

    expect(plan, isA<SingleColumn>());
    expect((plan as SingleColumn).panels, panels);
  });

  test('an empty panel list produces an empty plan at any width', () {
    expect((planLayout([], 1200) as TwoColumn).wide, isEmpty);
    expect((planLayout([], 1200) as TwoColumn).narrow, isEmpty);
    expect((planLayout([], 500) as SingleColumn).panels, isEmpty);
  });

  test('two-column mode preserves multiple panels per slot', () {
    final secondHost = _panel('host:webdock2', PanelSlot.narrow);
    final plan = planLayout([uptime, host, secondHost], 1200) as TwoColumn;

    expect(plan.wide, [uptime]);
    expect(plan.narrow, [host, secondHost]);
  });
}
