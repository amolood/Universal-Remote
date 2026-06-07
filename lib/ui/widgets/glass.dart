import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Wraps a child so that pressing fires [onTrigger] once immediately, then
/// repeatedly while held (after a short initial delay) — like a real remote's
/// volume/channel/arrow buttons. Plays a [haptic] tick per fire.
class HoldRepeat extends StatefulWidget {
  final Widget child;
  final VoidCallback onTrigger;
  final HapticStyle haptic;
  final Duration initialDelay;
  final Duration interval;

  const HoldRepeat({
    super.key,
    required this.child,
    required this.onTrigger,
    this.haptic = HapticStyle.nav,
    this.initialDelay = const Duration(milliseconds: 450),
    this.interval = const Duration(milliseconds: 120),
  });

  @override
  State<HoldRepeat> createState() => _HoldRepeatState();
}

class _HoldRepeatState extends State<HoldRepeat> {
  Timer? _initial;
  Timer? _repeat;

  void _fire() {
    switch (widget.haptic) {
      case HapticStyle.none:
        break;
      case HapticStyle.tap:
        Haptics.tap();
        break;
      case HapticStyle.nav:
        Haptics.nav();
        break;
      case HapticStyle.select:
        Haptics.select();
        break;
      case HapticStyle.confirm:
        Haptics.confirm();
        break;
      case HapticStyle.power:
        Haptics.power();
        break;
    }
    widget.onTrigger();
  }

  void _down() {
    _fire(); // immediate
    _initial = Timer(widget.initialDelay, () {
      _repeat = Timer.periodic(widget.interval, (_) => _fire());
    });
  }

  void _up() {
    _initial?.cancel();
    _repeat?.cancel();
    _initial = null;
    _repeat = null;
  }

  @override
  void dispose() {
    _up();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      child: widget.child,
    );
  }
}

/// A "frosted glass" container.
///
/// Performance note: this intentionally does NOT use `BackdropFilter`/
/// `ImageFilter.blur`. Real-time backdrop blur forces an offscreen `saveLayer`
/// per panel, and with a dozen panels on screen that dominates frame time on
/// mid-range phones. Instead we fake the frosted look with a translucent
/// vertical gradient fill + hairline highlight border, which is a plain
/// rect/gradient draw — effectively free — and visually nearly identical over
/// the dark aurora background.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Kept for API compatibility; ignored (no real blur is performed).
  final double blur;
  final Color? tint;
  final List<BoxShadow>? shadow;
  final Border? border;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.rMd,
    this.blur = 18,
    this.tint,
    this.shadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppTheme.softShadow,
        border:
            border ?? Border.all(color: AppTheme.glassStroke, width: 1),
        gradient: tint == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
              )
            : null,
        color: tint,
      ),
      child: child,
    );
  }
}

/// Haptic style a [Pressable] plays on press.
enum HapticStyle { none, tap, nav, select, confirm, power }

/// A pressable surface: springy scale-down on press, optional accent glow
/// pulse, and per-interaction haptics. The building block for every control.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final double scale;
  final HapticStyle haptic;

  /// When set, a soft glow of this color pulses on press (used for OK / power).
  final Color? glow;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.scale = 0.9,
    this.haptic = HapticStyle.tap,
    this.glow,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 220),
    lowerBound: 0,
    upperBound: 1,
  );

  late final Animation<double> _scaleAnim = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
    reverseCurve: Curves.elasticOut, // springy release
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case HapticStyle.none:
        break;
      case HapticStyle.tap:
        Haptics.tap();
        break;
      case HapticStyle.nav:
        Haptics.nav();
        break;
      case HapticStyle.select:
        Haptics.select();
        break;
      case HapticStyle.confirm:
        Haptics.confirm();
        break;
      case HapticStyle.power:
        Haptics.power();
        break;
    }
  }

  void _down(_) {
    _c.forward();
    _fireHaptic();
    widget.onTapDown?.call();
  }

  void _up(_) {
    _c.reverse();
    widget.onTapUp?.call();
  }

  @override
  Widget build(BuildContext context) {
    final interactive =
        widget.onTap != null || widget.onTapDown != null || widget.onTapUp != null;
    return GestureDetector(
      onTapDown: interactive ? _down : null,
      onTapUp: interactive ? _up : null,
      onTapCancel: () => _c.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) {
          final t = _scaleAnim.value.clamp(0.0, 1.0);
          final scale = 1 - t * (1 - widget.scale);
          Widget result = Transform.scale(scale: scale, child: child);
          if (widget.glow != null) {
            result = DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.glow!.withValues(alpha: 0.55 * t),
                    blurRadius: 26 * t,
                    spreadRadius: 2 * t,
                  ),
                ],
              ),
              child: result,
            );
          }
          return result;
        },
        child: widget.child,
      ),
    );
  }
}

/// A circular glass button with an icon and an optional accent glow.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? glowColor;
  final Color? iconColor;
  final String? tooltip;
  final HapticStyle haptic;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 60,
    this.iconSize = 26,
    this.glowColor,
    this.iconColor,
    this.tooltip,
    this.haptic = HapticStyle.tap,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Pressable(
      onTap: onTap,
      haptic: haptic,
      glow: glowColor,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
          ),
          border: Border.all(color: AppTheme.glassStroke, width: 1),
          boxShadow: glowColor != null
              ? AppTheme.glow(glowColor!, strength: 0.35)
              : AppTheme.softShadow,
        ),
        child: Icon(icon, size: iconSize, color: iconColor ?? AppTheme.textHi),
      ),
    );
    final wrapped =
        tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
    // Expose to screen readers (TalkBack/VoiceOver) as a labelled button.
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: wrapped,
    );
  }
}

/// A wide gradient "primary action" button.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Pressable(
      scale: 0.96,
      onTap: enabled ? onTap : null,
      haptic: enabled ? HapticStyle.confirm : HapticStyle.none,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(AppTheme.rMd),
            boxShadow: AppTheme.glow(AppTheme.accent, strength: 0.45),
          ),
          child: busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
