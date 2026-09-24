import 'package:flutter_test/flutter_test.dart';
import 'package:kurokan/features/vps/presentation/host_status_glyph.dart';
import 'package:kurokan/shared/widgets/status_glyph.dart';

void main() {
  test('maps every known host status to its glyph', () {
    expect(hostStatusGlyph('running'), StatusGlyphs.up);
    expect(hostStatusGlyph('stopped'), StatusGlyphs.muted);
    expect(hostStatusGlyph('suspended'), StatusGlyphs.muted);
    expect(hostStatusGlyph('error'), StatusGlyphs.down);
  });

  test('falls back to the pending glyph for a transitional status', () {
    for (final status in [
      'provisioning',
      'starting',
      'rebooting',
      'stopping',
      'reinstalling',
      'something-unrecognized',
    ]) {
      expect(hostStatusGlyph(status), StatusGlyphs.pending);
    }
  });
}
