import 'package:flutter/material.dart';

import '../theme.dart';
import '../../atv/key_codes.dart';
import '../../i18n/strings.dart';
import 'glass.dart';

/// A swipe touchpad: drag in a direction to send the matching D-pad key, tap
/// the center to send OK. Mirrors the Apple TV / Google TV trackpad feel.
///
/// Swipes are recognised as discrete flicks: when the cumulative drag passes a
/// threshold, the corresponding key fires once and the gesture resets, so a
/// long fast swipe = one navigation step (like a physical remote).
class Touchpad extends StatefulWidget {
  final void Function(int keyCode) onKey;
  final VoidCallback onOk;

  /// When provided, dragging emits raw pointer deltas (real cursor move) via
  /// [onMove] instead of swipe-to-DPAD. Used for protocols with a real pointer.
  final void Function(double dx, double dy)? onMove;

  const Touchpad({
    super.key,
    required this.onKey,
    required this.onOk,
    this.onMove,
  });

  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 44;

  Offset _accum = Offset.zero;
  Offset _ripple = Offset.zero;
  bool _fired = false;

  late final AnimationController _rippleC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _rippleC.dispose();
    super.dispose();
  }

  void _showRipple(Offset local) {
    setState(() => _ripple = local);
    _rippleC.forward(from: 0);
  }

  void _onPanStart(DragStartDetails d) {
    _accum = Offset.zero;
    _fired = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // Real-cursor mode: forward raw deltas (scaled up for a snappy feel).
    if (widget.onMove != null) {
      widget.onMove!(d.delta.dx * 1.6, d.delta.dy * 1.6);
      return;
    }
    if (_fired) return;
    _accum += d.delta;
    if (_accum.distance < _threshold) return;

    final dx = _accum.dx, dy = _accum.dy;
    final int key;
    if (dx.abs() > dy.abs()) {
      key = dx > 0 ? KeyCode.dpadRight : KeyCode.dpadLeft;
    } else {
      key = dy > 0 ? KeyCode.dpadDown : KeyCode.dpadUp;
    }
    _fired = true;
    Haptics.select();
    widget.onKey(key);
    _showRipple(d.localPosition);
  }

  void _onTapUp(TapUpDetails d) {
    Haptics.tap();
    widget.onOk();
    _showRipple(d.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        container: true,
        label: S.of(context).touchpad,
        hint: S.of(context).touchpadHint,
        child: GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onTapUp: _onTapUp,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.rXl),
          child: Stack(
            children: [
              // Glass surface
              GlassPanel(
                radius: AppTheme.rXl,
                padding: EdgeInsets.zero,
                blur: 22,
                child: const SizedBox.expand(),
              ),
              // Directional hint arrows (faint)
              const Positioned.fill(child: _DirectionHints()),
              // Center OK ring
              const Center(child: _OkRing()),
              // Touch ripple
              AnimatedBuilder(
                animation: _rippleC,
                builder: (context, _) {
                  if (_rippleC.isDismissed) return const SizedBox.shrink();
                  final v = Curves.easeOut.transform(_rippleC.value);
                  return Positioned(
                    left: _ripple.dx - 60,
                    top: _ripple.dy - 60,
                    child: Opacity(
                      opacity: (1 - v) * 0.6,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.accent.withValues(alpha: 0.0),
                              AppTheme.accent.withValues(alpha: 0.5),
                            ],
                            stops: [v * 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}

class _DirectionHints extends StatelessWidget {
  const _DirectionHints();

  @override
  Widget build(BuildContext context) {
    const c = AppTheme.textLo;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.keyboard_arrow_up, color: c, size: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Icon(Icons.keyboard_arrow_left, color: c, size: 28),
              Icon(Icons.keyboard_arrow_right, color: c, size: 28),
            ],
          ),
          const Icon(Icons.keyboard_arrow_down, color: c, size: 28),
        ],
      ),
    );
  }
}

class _OkRing extends StatelessWidget {
  const _OkRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.glassStroke, width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'OK',
        style: TextStyle(
          color: AppTheme.textHi,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
