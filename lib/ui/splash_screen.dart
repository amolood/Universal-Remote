import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import 'theme.dart';
import 'widgets/aurora_background.dart';

/// Brief startup screen shown while the saved pairing loads from disk.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final v = Curves.easeOutBack.transform(_c.value.clamp(0, 1));
              return Opacity(
                opacity: _c.value.clamp(0, 1),
                child: Transform.scale(scale: 0.8 + v * 0.2, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.rLg),
                    gradient: AppTheme.accentGradient,
                    boxShadow: AppTheme.glow(AppTheme.accent, strength: 0.6),
                  ),
                  child: const Icon(Icons.settings_remote_rounded,
                      color: Colors.white, size: 58),
                ),
                const SizedBox(height: 24),
                const Text(
                  'TV Remote',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHi,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  S.of(context).appTagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMid, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
