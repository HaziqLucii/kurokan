import '../../../shared/widgets/status_glyph.dart';

/// Shared between the single-host detail view and the compact host table:
/// both render the same `HostVitals.status` vocabulary.
String hostStatusGlyph(String status) => switch (status) {
  'running' => StatusGlyphs.up,
  'stopped' || 'suspended' => StatusGlyphs.muted,
  'error' => StatusGlyphs.down,
  _ =>
    StatusGlyphs
        .pending, // provisioning/starting/rebooting/stopping/reinstalling
};
