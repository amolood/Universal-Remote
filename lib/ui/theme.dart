import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Direction-aware icon helpers. In RTL, "back" should visually point to the
/// right, so these return the mirrored icon based on the ambient text
/// direction (set by the Localized widget).
class DirIcons {
  static IconData back(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.arrow_forward_rounded
          : Icons.arrow_back_rounded;

  static IconData chevronBack(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_right_rounded
          : Icons.chevron_left_rounded;

  static IconData chevronForward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded;
}

/// Centralised design tokens for the "Modern Dark + Glass" aesthetic.
class AppTheme {
  AppTheme._();

  // --- Palette ---
  static const Color bg0 = Color(0xFF07080C); // deepest background
  static const Color bg1 = Color(0xFF0D0F16); // base background
  static const Color surface = Color(0xFF14171F); // raised surface
  static const Color glassTint = Color(0x14FFFFFF); // 8% white glass fill
  static const Color glassStroke = Color(0x1FFFFFFF); // hairline border

  static const Color accent = Color(0xFF5B8CFF); // primary blue
  static const Color accent2 = Color(0xFF9B6BFF); // violet
  static const Color accentPink = Color(0xFFFF6BC1);
  static const Color success = Color(0xFF3DD68C);
  static const Color warning = Color(0xFFFFC24B);
  static const Color danger = Color(0xFFFF5C73);

  static const Color textHi = Color(0xFFF2F4F8);
  static const Color textMid = Color(0xFFAAB2C5);
  static const Color textLo = Color(0xFF6B7280);

  // --- Gradients ---
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );

  static const RadialGradient bgGlow = RadialGradient(
    center: Alignment(0, -0.7),
    radius: 1.3,
    colors: [Color(0xFF1A2140), bg1, bg0],
    stops: [0.0, 0.55, 1.0],
  );

  // --- Radii / spacing ---
  static const double rSm = 14;
  static const double rMd = 22;
  static const double rLg = 30;
  static const double rXl = 40;

  // --- Shadows ---
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> glow(Color color, {double strength = 0.5}) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 28,
          spreadRadius: -4,
        ),
      ];

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: surface,
      primary: accent,
      secondary: accent2,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg1,
      fontFamily: 'SF Pro Display',
      textTheme: const TextTheme().apply(
        bodyColor: textHi,
        displayColor: textHi,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Haptic helpers tuned per interaction type for a tactile remote feel.
/// All calls are no-ops when [enabled] is false (user setting).
class Haptics {
  static bool enabled = true;

  /// Standard button press — a crisp light tap.
  static void tap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// D-pad / navigation step — selection click (subtle, repeatable).
  static void nav() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// OK / confirm — slightly firmer.
  static void confirm() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Toggle / mode switch.
  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Important / destructive action.
  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// Power button — double pulse for a distinct feel.
  static Future<void> power() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }
}
