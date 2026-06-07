import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../atv/atv_controller.dart';
import '../i18n/strings.dart';
import 'theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass.dart';

/// Settings — remote layout, haptics, language, about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AtvController>();
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 16, 8),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.chevron_left_rounded,
                      size: 42,
                      iconSize: 26,
                      onTap: () => Navigator.pop(context),
                      tooltip: s.back,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s.settings,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textHi,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _SectionLabel(s.remoteLayout),
                    ...RemoteLayout.values.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _LayoutCard(
                            layout: l,
                            selected: c.layout == l,
                            onTap: () {
                              Haptics.select();
                              c.setLayout(l);
                            },
                          ),
                        )),
                    const SizedBox(height: 20),
                    _SectionLabel(s.language),
                    GlassPanel(
                      radius: AppTheme.rMd,
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: AppLang.values.map((l) {
                          final active = c.lang == l;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Haptics.select();
                                c.setLang(l);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.rSm),
                                  gradient:
                                      active ? AppTheme.accentGradient : null,
                                ),
                                child: Text(
                                  l.nativeName,
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : AppTheme.textMid,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(s.feedback),
                    GlassPanel(
                      radius: AppTheme.rMd,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.vibration_rounded,
                              color: AppTheme.textHi, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(s.hapticFeedback,
                                style: const TextStyle(
                                    color: AppTheme.textHi, fontSize: 16)),
                          ),
                          Switch(
                            value: c.hapticsEnabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppTheme.accent,
                            onChanged: (v) {
                              c.setHaptics(v);
                              if (v) Haptics.confirm();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      radius: AppTheme.rMd,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.threed_rotation_rounded,
                                  color: AppTheme.textHi, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(s.airMouseSpeed,
                                    style: const TextStyle(
                                        color: AppTheme.textHi, fontSize: 16)),
                              ),
                              Text('${c.mouseSensitivity.toStringAsFixed(1)}×',
                                  style: const TextStyle(
                                      color: AppTheme.textMid, fontSize: 13)),
                            ],
                          ),
                          Slider(
                            value: c.mouseSensitivity,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            activeColor: AppTheme.accent,
                            onChanged: (v) => c.setMouseSensitivity(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(s.about),
                    GlassPanel(
                      radius: AppTheme.rMd,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.rSm),
                              gradient: AppTheme.accentGradient,
                            ),
                            child: const Icon(Icons.settings_remote_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TV Remote',
                                  style: TextStyle(
                                      color: AppTheme.textHi,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(s.appTagline,
                                  style: const TextStyle(
                                      color: AppTheme.textMid, fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          Text('v${c.appVersion}',
                              style: const TextStyle(
                                  color: AppTheme.textMid, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  final RemoteLayout layout;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutCard({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      haptic: HapticStyle.select,
      onTap: onTap,
      child: GlassPanel(
        radius: AppTheme.rLg,
        padding: const EdgeInsets.all(16),
        border: selected
            ? Border.all(color: AppTheme.accent, width: 1.6)
            : null,
        child: Row(
          children: [
            _LayoutThumb(layout: layout, selected: selected),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(S.of(context), layout),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHi,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _desc(S.of(context), layout),
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppTheme.accentGradient : null,
                border: selected
                    ? null
                    : Border.all(color: AppTheme.glassStroke, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny schematic preview of each layout.
class _LayoutThumb extends StatelessWidget {
  final RemoteLayout layout;
  final bool selected;
  const _LayoutThumb({required this.layout, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: AppTheme.glassStroke),
      ),
      child: CustomPaint(
        painter: _ThumbPainter(
          layout: layout,
          accent: selected ? AppTheme.accent : AppTheme.textMid,
        ),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final RemoteLayout layout;
  final Color accent;
  _ThumbPainter({required this.layout, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppTheme.textLo;
    final hi = Paint()..color = accent;
    final w = size.width, h = size.height;

    void bar(double y, {int n = 4, Paint? p}) {
      final gap = w / (n + 1);
      for (var i = 1; i <= n; i++) {
        canvas.drawCircle(Offset(gap * i, y), 2.2, p ?? dot);
      }
    }

    void dpad(double cy, double r) {
      canvas.drawCircle(Offset(w / 2, cy), r, Paint()
        ..color = AppTheme.glassStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      canvas.drawCircle(Offset(w / 2, cy), r * 0.38, hi);
    }

    switch (layout) {
      case RemoteLayout.balanced:
        bar(h * 0.12);
        dpad(h * 0.45, w * 0.26);
        bar(h * 0.78, n: 5);
        bar(h * 0.93, n: 3);
        break;
      case RemoteLayout.minimal:
        dpad(h * 0.42, w * 0.34);
        bar(h * 0.85, n: 3);
        break;
      case RemoteLayout.touchpad:
        // big rounded pad
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, w - 4, h * 0.62),
          const Radius.circular(6),
        );
        canvas.drawRRect(
            rect,
            Paint()
              ..color = accent.withValues(alpha: 0.25)
              ..style = PaintingStyle.fill);
        canvas.drawRRect(
            rect,
            Paint()
              ..color = accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
        bar(h * 0.85, n: 5);
        break;
      case RemoteLayout.classic:
        // top row, centered dpad, and two side columns (VOL/CH)
        bar(h * 0.12);
        dpad(h * 0.45, w * 0.22);
        final side = Paint()
          ..color = accent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(3, h * 0.72, w * 0.22, h * 0.24),
                const Radius.circular(3)),
            side);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w - w * 0.22 - 3, h * 0.72, w * 0.22, h * 0.24),
                const Radius.circular(3)),
            side);
        bar(h * 0.84, n: 1);
        break;
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.layout != layout || old.accent != accent;
}

String _label(S s, RemoteLayout l) => switch (l) {
      RemoteLayout.balanced => s.layoutBalanced,
      RemoteLayout.minimal => s.layoutMinimal,
      RemoteLayout.touchpad => s.layoutTouchpad,
      RemoteLayout.classic => s.layoutClassic,
    };

String _desc(S s, RemoteLayout l) => switch (l) {
      RemoteLayout.balanced => s.layoutBalancedDesc,
      RemoteLayout.minimal => s.layoutMinimalDesc,
      RemoteLayout.touchpad => s.layoutTouchpadDesc,
      RemoteLayout.classic => s.layoutClassicDesc,
    };

/// Uppercase section header used between settings groups.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMid,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
