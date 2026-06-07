import 'package:flutter/material.dart';

import '../theme.dart';

/// Ambient background: soft colored "blobs" behind a dark base.
///
/// Performance note: this is rendered ONCE and isolated behind a
/// [RepaintBoundary]. The earlier version drove a forever-repeating
/// `AnimationController`, which forced the whole background (three large radial
/// gradients) to repaint every single frame even while the user was idle —
/// pure wasted GPU. The drift was barely perceptible, so we drop it. The
/// result is a static gradient the rasterizer can cache.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppTheme.bg0),
      child: Stack(
        children: [
          const RepaintBoundary(child: _AuroraBlobs()),
          child,
        ],
      ),
    );
  }
}

class _AuroraBlobs extends StatelessWidget {
  const _AuroraBlobs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _blob(AppTheme.accent, const Alignment(-0.7, -0.8), 360),
        _blob(AppTheme.accent2, const Alignment(0.8, -0.2), 320),
        _blob(AppTheme.accentPink, const Alignment(0.3, 0.85), 280),
        // Darkening veil keeps the blobs subtle.
        Positioned.fill(
          child: ColoredBox(color: AppTheme.bg0.withValues(alpha: 0.55)),
        ),
      ],
    );
  }

  Widget _blob(Color color, Alignment alignment, double size) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
