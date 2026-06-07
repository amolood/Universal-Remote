import 'package:atv_remote/atv/cvte_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CvteCursor', () {
    test('starts centred on the surface', () {
      final c = CvteCursor();
      expect(c.x, CvteCursor.surfaceW / 2);
      expect(c.y, CvteCursor.surfaceH / 2);
    });

    test('integrates deltas with the movement gain', () {
      final c = CvteCursor();
      final startX = c.x;
      c.move(10, 0);
      expect(c.x, closeTo(startX + 10 * CvteCursor.gain, 1e-9));
      expect(c.y, CvteCursor.surfaceH / 2); // unchanged
    });

    test('accumulates successive moves', () {
      final c = CvteCursor();
      final startX = c.x;
      c.move(4, 0);
      c.move(6, 0);
      expect(c.x, closeTo(startX + 10 * CvteCursor.gain, 1e-9));
    });

    test('clamps at the right/bottom edges', () {
      final c = CvteCursor();
      c.move(100000, 100000);
      expect(c.x, CvteCursor.surfaceW);
      expect(c.y, CvteCursor.surfaceH);
    });

    test('clamps at the left/top edges', () {
      final c = CvteCursor();
      c.move(-100000, -100000);
      expect(c.x, 0);
      expect(c.y, 0);
    });

    test('recenter resets to the middle', () {
      final c = CvteCursor();
      c.move(500, 300);
      c.recenter();
      expect(c.x, CvteCursor.surfaceW / 2);
      expect(c.y, CvteCursor.surfaceH / 2);
    });
  });
}
