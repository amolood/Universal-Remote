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

  /// Low-pass smoothing factor in [0,1): each sample is blended with the
  /// previous filtered value as `out = out*(1-a) + sample*a`. Lower = smoother
  /// but laggier; higher = snappier but jitterier. 0 disables smoothing.
  final double smoothing;

  AirMouse({
    this.sensitivity = 14.0,
    this.deadZone = 0.02,
    this.smoothing = 0.35,
  });

  // Filtered velocity carried between samples.
  double _fx = 0, _fy = 0;

  bool get isRunning => _sub != null;

  /// Starts emitting (dx, dy) pointer deltas to [onMove] until [stop].
  void start(void Function(double dx, double dy) onMove) {
    _sub?.cancel();
    _fx = 0;
    _fy = 0;
    final a = smoothing.clamp(0.0, 1.0);
    _sub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 16), // ~60Hz
    ).listen((e) {
      // Map device axes to screen axes (portrait hold):
      //   yaw   = e.z -> horizontal (invert so rotating right moves right)
      //   pitch = e.x -> vertical
      var rx = -e.z;
      var ry = -e.x;
      if (rx.abs() < deadZone) rx = 0;
      if (ry.abs() < deadZone) ry = 0;
      // Exponential moving average smooths out gyroscope noise/jitter.
      _fx = a == 0 ? rx : _fx * (1 - a) + rx * a;
      _fy = a == 0 ? ry : _fy * (1 - a) + ry * a;
      // Snap tiny residuals to zero so the cursor settles when the hand stops.
      if (_fx.abs() < 1e-3 && _fy.abs() < 1e-3) return;
      onMove(_fx * sensitivity, _fy * sensitivity);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() => stop();
}
