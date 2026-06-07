import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// Turns the phone's gyroscope into pointer movement — an "air mouse".
///
/// The gyroscope reports angular velocity (rad/s) about each axis. Holding the
/// phone like a remote and rotating it:
///   - yaw   (rotate left/right, gyro Z) -> horizontal cursor movement
///   - pitch (tilt up/down,     gyro X) -> vertical cursor movement
/// We integrate velocity into per-frame deltas, scaled to a comfortable
/// pointer speed, and drop tiny readings (dead zone) so the cursor sits still
/// when the hand is steady.
class AirMouse {
  StreamSubscription<GyroscopeEvent>? _sub;

  /// Sensitivity: pixels of movement per rad/s. Tune for feel.
  final double sensitivity;

  /// Dead zone (rad/s) below which motion is ignored.
  final double deadZone;

  AirMouse({this.sensitivity = 14.0, this.deadZone = 0.02});

  bool get isRunning => _sub != null;

  /// Starts emitting (dx, dy) pointer deltas to [onMove] until [stop].
  void start(void Function(double dx, double dy) onMove) {
    _sub?.cancel();
    _sub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 16), // ~60Hz
    ).listen((e) {
      // Map device axes to screen axes (portrait hold):
      //   yaw   = e.z -> horizontal (invert so rotating right moves right)
      //   pitch = e.x -> vertical
      var dx = -e.z;
      var dy = -e.x;
      if (dx.abs() < deadZone) dx = 0;
      if (dy.abs() < deadZone) dy = 0;
      if (dx == 0 && dy == 0) return;
      onMove(dx * sensitivity, dy * sensitivity);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() => stop();
}
