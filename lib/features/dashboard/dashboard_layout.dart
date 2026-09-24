import 'panel_registry.dart';

/// Compared against the whole window's width (WindowFrame's
/// `contentBuilder` width, before its ~100px fixed horizontal padding),
/// not the panel area's own width. Below it, the two side-by-side panel
/// columns no longer have room to breathe; everything stacks into one
/// scrollable column instead.
const dashboardLayoutBreakpoint = 900.0;

sealed class LayoutPlan {
  const LayoutPlan();
}

class TwoColumn extends LayoutPlan {
  final List<PanelEntry> wide;
  final List<PanelEntry> narrow;
  const TwoColumn({required this.wide, required this.narrow});
}

class SingleColumn extends LayoutPlan {
  final List<PanelEntry> panels;
  const SingleColumn({required this.panels});
}

/// Pure: same `panels`/`width` in, same plan out. Named `planLayout` (not
/// the plan doc's literal `plan`) to avoid a same-named local shadowing a
/// top-level function at dashboard_screen.dart's call site.
LayoutPlan planLayout(List<PanelEntry> panels, double width) {
  if (width >= dashboardLayoutBreakpoint) {
    return TwoColumn(
      wide: panels.where((p) => p.slot == PanelSlot.wide).toList(),
      narrow: panels.where((p) => p.slot == PanelSlot.narrow).toList(),
    );
  }
  return SingleColumn(panels: panels);
}
