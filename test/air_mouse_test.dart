import 'package:atv_remote/atv/air_mouse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AirMouse.processSample', () {
    test('drops motion inside the dead zone', () {
      final m = AirMouse(deadZone: 0.05, smoothing: 0.0);
      // Below the dead zone on both axes -> filtered out (returns null).
      expect(m.processSample(0.01, -0.02), isNull);
    });

    test('no smoothing scales raw velocity by sensitivity', () {
      final m = AirMouse(sensitivity: 10, deadZone: 0.0, smoothing: 0.0);
      final out = m.processSample(2.0, -1.0)!;
      expect(out.$1, closeTo(20.0, 1e-9));
      expect(out.$2, closeTo(-10.0, 1e-9));
    });

    test('smoothing lags toward a step input over successive samples', () {
      final m = AirMouse(sensitivity: 1, deadZone: 0.0, smoothing: 0.5);
      // Constant input of 1.0; EMA with a=0.5 should approach 1.0 each step:
      // 0.5, 0.75, 0.875, ...
      final s1 = m.processSample(1.0, 0)!.$1;
      final s2 = m.processSample(1.0, 0)!.$1;
      final s3 = m.processSample(1.0, 0)!.$1;
      expect(s1, closeTo(0.5, 1e-9));
      expect(s2, closeTo(0.75, 1e-9));
      expect(s3, closeTo(0.875, 1e-9));
      // Monotonically increasing toward the target.
      expect(s1 < s2 && s2 < s3, isTrue);
    });

    test('settles to null once the filtered value decays below threshold', () {
      final m = AirMouse(sensitivity: 1, deadZone: 0.0, smoothing: 0.5);
      m.processSample(1.0, 0); // charge the filter up
      // Now feed zeros; the EMA decays 0.5, 0.25, ... and eventually returns
      // null when both axes fall under the 1e-3 settle threshold.
      var settled = false;
      for (var i = 0; i < 30; i++) {
        if (m.processSample(0, 0) == null) {
          settled = true;
          break;
        }
      }
      expect(settled, isTrue);
    });

    test('reset clears carried filter state', () {
      final m = AirMouse(sensitivity: 1, deadZone: 0.0, smoothing: 0.5);
      m.processSample(1.0, 0);
      m.reset();
      // After reset, the first sample behaves like the very first one again.
      expect(m.processSample(1.0, 0)!.$1, closeTo(0.5, 1e-9));
    });
  });
}
