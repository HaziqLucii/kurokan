import 'package:flutter/widgets.dart';

import 'dashboard_layout.dart';
import 'panel_registry.dart';

/// A single-column cell needs a bounded height: some panels (VitalsPanel)
/// put a GridView inside an Expanded, which needs a finite constraint from
/// its ancestor, not the infinite height a bare ListView child would give.
const singleColumnCellHeight = 420.0;

class PanelGrid extends StatelessWidget {
  final LayoutPlan plan;
  const PanelGrid({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return switch (plan) {
      TwoColumn(:final wide, :final narrow) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 62, child: _PanelColumn(panels: wide)),
          const SizedBox(width: 40),
          Expanded(flex: 38, child: _PanelColumn(panels: narrow)),
        ],
      ),
      SingleColumn(:final panels) => ListView.separated(
        itemCount: panels.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, i) =>
            SizedBox(height: singleColumnCellHeight, child: panels[i].build()),
      ),
    };
  }
}

/// Stacks multiple panels in the same slot vertically (two-column mode
/// only): a config with more than one source of a kind gets more than one
/// panel per slot.
class _PanelColumn extends StatelessWidget {
  final List<PanelEntry> panels;
  const _PanelColumn({required this.panels});

  @override
  Widget build(BuildContext context) {
    if (panels.isEmpty) return const SizedBox.shrink();
    if (panels.length == 1) return panels.first.build();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final panel in panels) ...[
          Expanded(child: panel.build()),
          if (panel.key != panels.last.key) const SizedBox(height: 24),
        ],
      ],
    );
  }
}
