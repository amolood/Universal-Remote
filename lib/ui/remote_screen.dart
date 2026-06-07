import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../atv/atv_controller.dart';
import '../atv/key_codes.dart';
import '../atv/remote_client.dart';
import '../i18n/strings.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass.dart';
import 'widgets/touchpad.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen>
    with WidgetsBindingObserver {
  bool _touchpadMode = false; // default to D-pad (clearer for most users)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<AtvController>();
      if (!c.isConnected) c.connect();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final c = context.read<AtvController>();
      if (!c.isConnected && !c.busy) c.connect();
    }
  }

  void _openNumpad(AtvController c) {
    Haptics.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NumpadSheet(c: c),
    );
  }

  void _openKeyboard(AtvController c) {
    Haptics.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _KeyboardSheet(c: c),
    );
  }

  void _openRokuApps(AtvController c) {
    Haptics.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RokuAppsSheet(c: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read once (no rebuild on every notify). The header rebuilds itself on
    // connection changes; the body rebuilds only when the layout changes.
    final c = context.read<AtvController>();
    final layout = context.select<AtvController, RemoteLayout>((x) => x.layout);
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(c: c),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(layout),
                          child: _buildLayout(c, layout),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Listening overlay while voice is active.
              const _ListeningOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(AtvController c, RemoteLayout layout) {
    switch (layout) {
      case RemoteLayout.minimal:
        return _minimalLayout(c);
      case RemoteLayout.touchpad:
        return _touchpadLayout(c);
      case RemoteLayout.classic:
        return _ClassicLayout(
          c: c,
          onKeyboard: () => _openKeyboard(c),
          onNumpad: () => _openNumpad(c),
        );
      case RemoteLayout.balanced:
        return _balancedLayout(c);
    }
  }

  Widget _navArea(AtvController c, {required bool touchpad}) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(a),
            child: child,
          ),
        ),
        child: touchpad
            ? Touchpad(
                key: const ValueKey('tp'),
                onKey: c.sendKey,
                onOk: () => c.sendKey(KeyCode.dpadCenter),
              )
            : _DPad(key: const ValueKey('dpad'), c: c),
      ),
    );
  }

  // --- Balanced (default): everything, with a dpad/touchpad toggle ---
  Widget _balancedLayout(AtvController c) {
    return Column(
      children: [
        _UtilityRow(c: c),
        const SizedBox(height: 12),
        _ModeToggle(
          touchpad: _touchpadMode,
          onChanged: (v) => setState(() => _touchpadMode = v),
        ),
        const SizedBox(height: 10),
        Expanded(child: _navArea(c, touchpad: _touchpadMode)),
        const SizedBox(height: 10),
        _NavRow(
          c: c,
          onKeyboard: () => _openKeyboard(c),
          onNumpad: () => _openNumpad(c),
          onRokuApps: () => _openRokuApps(c),
        ),
        const SizedBox(height: 12),
        _MediaBar(c: c),
        const SizedBox(height: 10),
        _VolumeChannelRow(c: c),
      ],
    );
  }

  // --- Minimal: big dpad + back/home + volume only ---
  Widget _minimalLayout(AtvController c) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(child: Center(child: _DPad(c: c))),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GlassIconButton(
              icon: DirIcons.back(context),
              size: 58,
              onTap: () => c.sendKey(KeyCode.back),
              tooltip: S.of(context).back,
            ),
            GlassIconButton(
              icon: Icons.home_rounded,
              size: 58,
              glowColor: AppTheme.accent,
              onTap: () => c.sendKey(KeyCode.home),
              tooltip: S.of(context).home,
            ),
            GlassIconButton(
              icon: Icons.power_settings_new_rounded,
              size: 58,
              glowColor: AppTheme.danger,
              iconColor: AppTheme.danger,
              haptic: HapticStyle.power,
              onTap: () => c.sendKey(KeyCode.power),
              tooltip: S.of(context).power,
            ),
            // Air mouse (gyroscope) toggle.
            _AirMouseButton(c: c, size: 58),
          ],
        ),
        const SizedBox(height: 16),
        _VolumeChannelRow(c: c),
      ],
    );
  }

  // --- Touchpad-first: large swipe pad + compact button row ---
  Widget _touchpadLayout(AtvController c) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Expanded(
          child: Touchpad(
            onKey: c.sendKey,
            onOk: () => c.sendKey(KeyCode.dpadCenter),
            // Drag = real cursor move (CVTE) or dpad steps (Android TV).
            onMove: c.moveCursor,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GlassIconButton(
              icon: DirIcons.back(context),
              size: 50,
              onTap: () => c.sendKey(KeyCode.back),
              tooltip: S.of(context).back,
            ),
            GlassIconButton(
              icon: Icons.home_rounded,
              size: 50,
              onTap: () => c.sendKey(KeyCode.home),
              tooltip: S.of(context).home,
            ),
            // Air mouse (gyroscope) toggle.
            _AirMouseButton(c: c, size: 50),
            GlassIconButton(
              icon: Icons.keyboard_rounded,
              size: 50,
              onTap: () => _openKeyboard(c),
              tooltip: S.of(context).keyboard,
            ),
            _MicButton(c: c, size: 50),
          ],
        ),
        const SizedBox(height: 14),
        _VolumeChannelRow(c: c),
      ],
    );
  }
}

// ============================ Header ============================

class _Header extends StatelessWidget {
  final AtvController c;
  const _Header({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Rebuild only on connection-state changes (and name, which is stable).
    final conn = context
        .select<AtvController, RemoteConnectionState>((x) => x.connection);
    final (color, label) = switch (conn) {
      RemoteConnectionState.connected => (AppTheme.success, s.connected),
      RemoteConnectionState.connecting => (AppTheme.warning, s.connecting),
      RemoteConnectionState.disconnected => (AppTheme.danger, s.disconnected),
    };
    final connected = conn == RemoteConnectionState.connected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 4),
      child: Row(
        children: [
          GlassIconButton(
            icon: DirIcons.chevronBack(context),
            size: 42,
            iconSize: 26,
            onTap: () => c.backToDiscovery(),
            tooltip: S.of(context).switchTv,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.tvName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHi,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _PulsingDot(color: color),
                    const SizedBox(width: 7),
                    Text(label, style: TextStyle(color: color, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          if (!connected)
            GlassIconButton(
              icon: Icons.refresh_rounded,
              size: 42,
              iconSize: 20,
              onTap: () => c.connect(),
            ),
          const SizedBox(width: 6),
          GlassIconButton(
            icon: Icons.settings_rounded,
            size: 42,
            iconSize: 20,
            onTap: () {
              Haptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: S.of(context).settings,
          ),
          const SizedBox(width: 6),
          _MenuButton(c: c),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final AtvController c;
  const _MenuButton({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHi),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.rSm),
      ),
      onSelected: (v) async {
        if (v == 'switch') {
          Haptics.tap();
          c.backToDiscovery();
        } else if (v == 'forget') {
          Haptics.heavy();
          final ok = await _confirmUnpair(context, c.tvName);
          if (ok) c.forget();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'switch',
          child: Row(children: [
            const Icon(Icons.swap_horiz_rounded,
                size: 18, color: AppTheme.textHi),
            const SizedBox(width: 10),
            Text(s.switchTv, style: const TextStyle(color: AppTheme.textHi)),
          ]),
        ),
        PopupMenuItem(
          value: 'forget',
          child: Row(children: [
            const Icon(Icons.link_off_rounded, size: 18, color: AppTheme.danger),
            const SizedBox(width: 10),
            Text(s.unpairTv, style: const TextStyle(color: AppTheme.danger)),
          ]),
        ),
      ],
    );
  }

  Future<bool> _confirmUnpair(BuildContext context, String name) async {
    final s = S.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rMd),
        ),
        title: Text(s.unpairConfirmTitle,
            style: const TextStyle(color: AppTheme.textHi)),
        content: Text(
          s.unpairConfirmBody(name),
          style: const TextStyle(color: AppTheme.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textMid),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(s.unpair),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 + _c.value * 0.5),
                blurRadius: 8,
                spreadRadius: _c.value * 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== Utility / Nav rows ======================

class _UtilityRow extends StatelessWidget {
  final AtvController c;
  const _UtilityRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GlassIconButton(
          icon: Icons.power_settings_new_rounded,
          glowColor: AppTheme.danger,
          iconColor: AppTheme.danger,
          haptic: HapticStyle.power,
          onTap: () => c.sendKey(KeyCode.power),
          tooltip: S.of(context).power,
        ),
        GlassIconButton(
          icon: Icons.input_rounded,
          onTap: () => c.sendKey(KeyCode.input),
          tooltip: S.of(context).source,
        ),
        GlassIconButton(
          icon: Icons.tune_rounded,
          onTap: () => c.sendKey(KeyCode.settings),
          tooltip: S.of(context).settings,
        ),
        // Air mouse (gyroscope) toggle.
        _AirMouseButton(c: c, size: 60),
        _MicButton(c: c, size: 60),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  final AtvController c;
  final VoidCallback onKeyboard;
  final VoidCallback onNumpad;
  final VoidCallback? onRokuApps;
  const _NavRow({
    required this.c,
    required this.onKeyboard,
    required this.onNumpad,
    this.onRokuApps,
  });

  @override
  Widget build(BuildContext context) {
    // The apps grid is Roku-only; show it in place of the keyboard there.
    final isRoku = context.select<AtvController, bool>(
        (x) => x.activeProtocol == RemoteProtocol.roku);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GlassIconButton(
          icon: DirIcons.back(context),
          size: 54,
          onTap: () => c.sendKey(KeyCode.back),
          tooltip: S.of(context).back,
        ),
        GlassIconButton(
          icon: Icons.home_rounded,
          size: 54,
          glowColor: AppTheme.accent,
          onTap: () => c.sendKey(KeyCode.home),
          tooltip: S.of(context).home,
        ),
        GlassIconButton(
          icon: Icons.dialpad_rounded,
          size: 54,
          onTap: onNumpad,
          tooltip: S.of(context).numbers,
        ),
        if (isRoku && onRokuApps != null)
          GlassIconButton(
            icon: Icons.apps_rounded,
            size: 54,
            glowColor: const Color(0xFF6E2EE6),
            onTap: onRokuApps!,
            tooltip: S.of(context).apps,
          )
        else
          GlassIconButton(
            icon: Icons.keyboard_rounded,
            size: 54,
            onTap: onKeyboard,
            tooltip: S.of(context).keyboard,
          ),
      ],
    );
  }
}

// ============================ Mode toggle ============================

class _ModeToggle extends StatelessWidget {
  final bool touchpad;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.touchpad, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        radius: AppTheme.rXl,
        padding: const EdgeInsets.all(5),
        blur: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment(S.of(context).dpad, Icons.gamepad_rounded, !touchpad,
                () => onChanged(false)),
            _segment(S.of(context).touchpad, Icons.touch_app_rounded, touchpad,
                () => onChanged(true)),
          ],
        ),
      ),
    );
  }

  Widget _segment(
      String label, IconData icon, bool selected, VoidCallback onTap) {
    return Pressable(
      scale: 0.95,
      haptic: HapticStyle.select,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.rXl),
          gradient: selected ? AppTheme.accentGradient : null,
          boxShadow:
              selected ? AppTheme.glow(AppTheme.accent, strength: 0.35) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18, color: selected ? Colors.white : AppTheme.textMid),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMid,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ D-Pad ============================

class _DPad extends StatelessWidget {
  final AtvController c;
  const _DPad({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 268, maxHeight: 268),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              GlassPanel(
                radius: 999,
                padding: EdgeInsets.zero,
                blur: 18,
                child: const SizedBox.expand(),
              ),
              // Direction arrows
              Align(
                alignment: Alignment.topCenter,
                child: _arrow(context, Icons.keyboard_arrow_up_rounded,
                    S.of(context).up, () => c.sendKey(KeyCode.dpadUp)),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _arrow(context, Icons.keyboard_arrow_down_rounded,
                    S.of(context).down, () => c.sendKey(KeyCode.dpadDown)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _arrow(context, Icons.keyboard_arrow_left_rounded,
                    S.of(context).left, () => c.sendKey(KeyCode.dpadLeft)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _arrow(context, Icons.keyboard_arrow_right_rounded,
                    S.of(context).right, () => c.sendKey(KeyCode.dpadRight)),
              ),
              // OK center
              Semantics(
                button: true,
                label: S.of(context).ok,
                excludeSemantics: true,
                child: Pressable(
                  scale: 0.88,
                  haptic: HapticStyle.confirm,
                  glow: AppTheme.accent,
                  onTap: () => c.sendKey(KeyCode.dpadCenter),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                      boxShadow: AppTheme.glow(AppTheme.accent, strength: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: const Text('OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                          letterSpacing: 1,
                        )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: 70,
        height: 70,
        child: HoldRepeat(
          onTrigger: onTap,
          // Slower repeat than volume — navigation steps shouldn't race.
          initialDelay: const Duration(milliseconds: 500),
          interval: const Duration(milliseconds: 180),
          child: Center(
            child: Icon(icon, size: 36, color: AppTheme.textHi),
          ),
        ),
      ),
    );
  }
}

// ============================ Media ============================

class _MediaBar extends StatelessWidget {
  final AtvController c;
  const _MediaBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppTheme.rLg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _icon(Icons.fast_rewind_rounded,
              () => c.sendKey(KeyCode.mediaRewind)),
          _icon(Icons.skip_previous_rounded,
              () => c.sendKey(KeyCode.mediaPrevious)),
          _icon(Icons.play_arrow_rounded,
              () => c.sendKey(KeyCode.mediaPlayPause),
              big: true),
          _icon(Icons.skip_next_rounded, () => c.sendKey(KeyCode.mediaNext)),
          _icon(Icons.fast_forward_rounded,
              () => c.sendKey(KeyCode.mediaFastForward)),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, VoidCallback onTap, {bool big = false}) {
    return Pressable(
      scale: 0.85,
      glow: big ? AppTheme.accent : null,
      haptic: HapticStyle.tap,
      onTap: onTap,
      child: Container(
        width: big ? 52 : 44,
        height: big ? 52 : 44,
        decoration: big
            ? const BoxDecoration(
                shape: BoxShape.circle, gradient: AppTheme.accentGradient)
            : null,
        child: Icon(icon,
            size: big ? 30 : 26, color: big ? Colors.white : AppTheme.textHi),
      ),
    );
  }
}

// ====================== Volume + Channel ======================

class _VolumeChannelRow extends StatelessWidget {
  final AtvController c;
  const _VolumeChannelRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RockerPill(
            icon: Icons.volume_up_rounded,
            label: S.of(context).volShort,
            onUp: () => c.sendKey(KeyCode.volumeUp),
            onDown: () => c.sendKey(KeyCode.volumeDown),
          ),
        ),
        const SizedBox(width: 10),
        GlassIconButton(
          icon: Icons.volume_off_rounded,
          size: 56,
          iconSize: 24,
          onTap: () => c.sendKey(KeyCode.volumeMute),
          tooltip: S.of(context).mute,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RockerPill(
            icon: Icons.live_tv_rounded,
            label: S.of(context).chShort,
            onUp: () => c.sendKey(KeyCode.channelUp),
            onDown: () => c.sendKey(KeyCode.channelDown),
          ),
        ),
      ],
    );
  }
}

/// A vertical-feel rocker: minus on the left, label+icon in the middle, plus
/// on the right. Used for both Volume and Channel.
class _RockerPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onUp;
  final VoidCallback onDown;
  const _RockerPill({
    required this.icon,
    required this.label,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppTheme.rXl,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          HoldRepeat(
            onTrigger: onDown,
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(Icons.remove_rounded, color: AppTheme.textHi),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppTheme.textMid),
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textMid,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ],
            ),
          ),
          HoldRepeat(
            onTrigger: onUp,
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(Icons.add_rounded, color: AppTheme.textHi),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================== Numpad sheet ======================

class _NumpadSheet extends StatelessWidget {
  final AtvController c;
  const _NumpadSheet({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassPanel(
        radius: AppTheme.rLg,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppTheme.glassStroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.5,
              children: [
                for (var n = 1; n <= 9; n++) _digit(n),
                _ghost(),
                _digit(0),
                _ghost(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _digit(int n) {
    return Pressable(
      scale: 0.9,
      haptic: HapticStyle.tap,
      onTap: () => c.sendKey(KeyCode.digit(n)),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.glassTint,
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          border: Border.all(color: AppTheme.glassStroke),
        ),
        child: Text('$n',
            style: const TextStyle(
                color: AppTheme.textHi,
                fontSize: 26,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _ghost() => const SizedBox.shrink();
}

// ====================== Keyboard sheet ======================

class _KeyboardSheet extends StatefulWidget {
  final AtvController c;
  const _KeyboardSheet({required this.c});

  @override
  State<_KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<_KeyboardSheet> {
  final _controller = TextEditingController();
  String _previous = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value.length > _previous.length && value.startsWith(_previous)) {
      widget.c.sendText(value.substring(_previous.length));
    } else if (value.length < _previous.length &&
        _previous.startsWith(value)) {
      for (var i = 0; i < _previous.length - value.length; i++) {
        widget.c.backspace();
      }
    } else {
      for (var i = 0; i < _previous.length; i++) {
        widget.c.backspace();
      }
      widget.c.sendText(value);
    }
    _previous = value;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: GlassPanel(
        radius: AppTheme.rLg,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.glassStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(S.of(context).typeOnTv,
                style: TextStyle(
                    color: AppTheme.textHi,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textHi),
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                widget.c.enter();
                Navigator.pop(context);
              },
              decoration: InputDecoration(
                hintText: S.of(context).searchOrType,
                hintStyle: const TextStyle(color: AppTheme.textLo),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.25),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.backspace_outlined,
                      color: AppTheme.textMid),
                  onPressed: () {
                    widget.c.backspace();
                    if (_controller.text.isNotEmpty) {
                      _controller.text = _controller.text
                          .substring(0, _controller.text.length - 1);
                      _previous = _controller.text;
                    }
                  },
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.rSm),
                  borderSide: const BorderSide(color: AppTheme.glassStroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.rSm),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: S.of(context).done,
              icon: Icons.check_rounded,
              onTap: () {
                widget.c.enter();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Push-to-talk mic button: hold to stream voice to the TV, release to stop.
/// Pulses red while recording.
class _MicButton extends StatefulWidget {
  final AtvController c;
  final double size;
  const _MicButton({required this.c, required this.size});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _down() async {
    Haptics.confirm();
    final ok = await widget.c.startVoice();
    if (!mounted) return;
    if (ok) {
      setState(() => _recording = true);
      _pulse.repeat(reverse: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.c.lastError ?? 'Voice unavailable'),
          backgroundColor: AppTheme.danger.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.rSm),
          ),
        ),
      );
    }
  }

  Future<void> _up() async {
    if (!_recording) return;
    await widget.c.stopVoice();
    if (!mounted) return;
    setState(() => _recording = false);
    _pulse.stop();
    _pulse.reset();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      label: S.of(context).mic,
      hint: _recording ? S.of(context).listening : null,
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = _recording ? AppTheme.danger : AppTheme.accent2;
          final pulse = _recording ? (0.4 + _pulse.value * 0.5) : 0.35;
          return Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _recording
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5C73), Color(0xFFFF8A5C)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
                    ),
              border: Border.all(color: AppTheme.glassStroke, width: 1),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: pulse),
                  blurRadius: _recording ? 24 : 16,
                  spreadRadius: _recording ? _pulse.value * 3 : -2,
                ),
              ],
            ),
            child: Icon(
              _recording ? Icons.mic : Icons.mic_none_rounded,
              size: s * 0.45,
              color: _recording ? Colors.white : AppTheme.textHi,
            ),
          );
          },
        ),
      ),
    );
  }
}

/// Bottom overlay shown while a voice session is active: an animated waveform
/// + "Listening…" so the user knows the mic is live.
class _ListeningOverlay extends StatelessWidget {
  const _ListeningOverlay();

  @override
  Widget build(BuildContext context) {
    final active = context.select<AtvController, bool>((c) => c.voiceActive);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: !active
          ? const SizedBox.shrink()
          : Align(
              key: const ValueKey('listening'),
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GlassPanel(
                  radius: AppTheme.rXl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  tint: AppTheme.danger.withValues(alpha: 0.14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Waveform(),
                      const SizedBox(width: 14),
                      Text(
                        S.of(context).listening,
                        style: const TextStyle(
                          color: AppTheme.textHi,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Waveform extends StatefulWidget {
  const _Waveform();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 24,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(5, (i) {
              final phase = (_c.value + i / 5) % 1.0;
              final h = 6 + (18 * (0.5 + 0.5 * _sin(phase)));
              return Container(
                width: 4,
                height: h,
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  double _sin(double t) {
    // cheap sine approximation via the standard lib
    return math.sin(t * 2 * math.pi);
  }
}

/// Classic TV-remote layout inspired by common universal-remote apps:
/// - top utility row (power / guide / input / home)
/// - large circular D-pad with OK center and arrows, plus four "corner" keys
///   (back / info / menu / exit) tucked around it
/// - vertical Volume and Channel rocker columns on the left/right, with
///   mute / numbers / keyboard stacked in the middle.
/// Built entirely with Material icons and our glass design system.
class _ClassicLayout extends StatelessWidget {
  final AtvController c;
  final VoidCallback onKeyboard;
  final VoidCallback onNumpad;
  const _ClassicLayout({
    required this.c,
    required this.onKeyboard,
    required this.onNumpad,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        // --- Top utility row: Power · Guide · Input · Home (Unimote order) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GlassIconButton(
              icon: Icons.power_settings_new_rounded,
              size: 52,
              glowColor: AppTheme.danger,
              iconColor: AppTheme.danger,
              haptic: HapticStyle.power,
              onTap: () => c.sendKey(KeyCode.power),
              tooltip: s.power,
            ),
            GlassIconButton(
              icon: Icons.menu_book_rounded,
              size: 52,
              onTap: () => c.sendKey(KeyCode.guide),
              tooltip: s.guide,
            ),
            GlassIconButton(
              icon: Icons.settings_input_hdmi_rounded,
              size: 52,
              onTap: () => c.sendKey(KeyCode.input),
              tooltip: s.input,
            ),
            GlassIconButton(
              icon: Icons.home_rounded,
              size: 52,
              glowColor: AppTheme.accent,
              onTap: () => c.sendKey(KeyCode.home),
              tooltip: s.home,
            ),
            // Air mouse (gyroscope) toggle.
            _AirMouseButton(c: c, size: 52),
          ],
        ),
        const SizedBox(height: 18),
        // --- Circular D-pad with corner keys ---
        Expanded(
          child: Center(
            child: _ClassicDpad(c: c),
          ),
        ),
        const SizedBox(height: 14),
        // --- Narrow side VOL / CH columns; center mute / numbers / keyboard ---
        SizedBox(
          height: 184,
          child: Row(
            children: [
              // Left VOL column — narrow vertical pill (like a real remote).
              SizedBox(
                width: 62,
                child: _VRocker(
                  icon: Icons.volume_up_rounded,
                  label: s.volShort,
                  onUp: () => c.sendKey(KeyCode.volumeUp),
                  onDown: () => c.sendKey(KeyCode.volumeDown),
                ),
              ),
              // Center column: Numbers · Mute · Keyboard — distinct from the
              // top row (Input/Home) and the corner keys (Menu/Info), so no
              // function is duplicated.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GlassIconButton(
                      icon: Icons.dialpad_rounded,
                      size: 52,
                      onTap: onNumpad,
                      tooltip: s.numbers,
                    ),
                    GlassIconButton(
                      icon: Icons.volume_off_rounded,
                      size: 52,
                      onTap: () => c.sendKey(KeyCode.volumeMute),
                      tooltip: s.mute,
                    ),
                    GlassIconButton(
                      icon: Icons.keyboard_rounded,
                      size: 52,
                      onTap: onKeyboard,
                      tooltip: s.keyboard,
                    ),
                  ],
                ),
              ),
              // Right CH column.
              SizedBox(
                width: 62,
                child: _VRocker(
                  icon: Icons.live_tv_rounded,
                  label: s.chShort,
                  onUp: () => c.sendKey(KeyCode.channelUp),
                  onDown: () => c.sendKey(KeyCode.channelDown),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular D-pad: outer glass ring, arrows at N/E/S/W, OK in the center, and
/// four small "corner" keys (back / info / menu / exit) around the ring —
/// matching the classic universal-remote arrangement.
class _ClassicDpad extends StatelessWidget {
  final AtvController c;
  const _ClassicDpad({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Corner keys, arranged like a classic remote:
            //   top-left  = tools/menu      top-right    = info
            //   bot-left  = back            bot-right    = exit
            Align(
              alignment: const Alignment(-0.95, -0.95),
              child: _corner(Icons.tune_rounded, s.menu,
                  () => c.sendKey(KeyCode.menu)),
            ),
            Align(
              alignment: const Alignment(0.95, -0.95),
              child: _corner(Icons.info_outline_rounded, s.info,
                  () => c.sendKey(KeyCode.info)),
            ),
            Align(
              alignment: const Alignment(-0.95, 0.95),
              child: _corner(DirIcons.back(context), s.back,
                  () => c.sendKey(KeyCode.back)),
            ),
            Align(
              alignment: const Alignment(0.95, 0.95),
              child: _corner(Icons.settings_rounded, s.settings,
                  () => c.sendKey(KeyCode.settings)),
            ),
            // Outer ring (slightly inset so corner keys sit at the edges)
            Padding(
              padding: const EdgeInsets.all(34),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GlassPanel(
                    radius: 999,
                    padding: EdgeInsets.zero,
                    child: const SizedBox.expand(),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: _arrow(context, Icons.keyboard_arrow_up_rounded,
                        s.up, () => c.sendKey(KeyCode.dpadUp)),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _arrow(context, Icons.keyboard_arrow_down_rounded,
                        s.down, () => c.sendKey(KeyCode.dpadDown)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _arrow(context, Icons.keyboard_arrow_left_rounded,
                        s.left, () => c.sendKey(KeyCode.dpadLeft)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _arrow(context, Icons.keyboard_arrow_right_rounded,
                        s.right, () => c.sendKey(KeyCode.dpadRight)),
                  ),
                  Semantics(
                    button: true,
                    label: s.ok,
                    excludeSemantics: true,
                    child: Pressable(
                      scale: 0.88,
                      haptic: HapticStyle.confirm,
                      glow: AppTheme.accent,
                      onTap: () => c.sendKey(KeyCode.dpadCenter),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.accentGradient,
                          boxShadow:
                              AppTheme.glow(AppTheme.accent, strength: 0.5),
                        ),
                        alignment: Alignment.center,
                        child: const Text('OK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: 1,
                            )),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corner(IconData icon, String label, VoidCallback onTap) {
    return GlassIconButton(
      icon: icon,
      size: 48,
      iconSize: 22,
      onTap: onTap,
      tooltip: label,
    );
  }

  Widget _arrow(BuildContext context, IconData icon, String label,
      VoidCallback onTap) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: 64,
        height: 64,
        child: HoldRepeat(
          onTrigger: onTap,
          initialDelay: const Duration(milliseconds: 500),
          interval: const Duration(milliseconds: 180),
          child: Center(child: Icon(icon, size: 34, color: AppTheme.textHi)),
        ),
      ),
    );
  }
}

/// Vertical rocker: + on top, label in the middle, − on the bottom. Both ends
/// repeat on long-press. Used for the Volume and Channel side columns.
class _VRocker extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onUp;
  final VoidCallback onDown;
  const _VRocker({
    required this.icon,
    required this.label,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppTheme.rXl,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Expanded(
            child: HoldRepeat(
              onTrigger: onUp,
              child: const Center(
                child: Icon(Icons.add_rounded,
                    color: AppTheme.textHi, size: 28),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.textMid),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ],
          ),
          Expanded(
            child: HoldRepeat(
              onTrigger: onDown,
              child: const Center(
                child: Icon(Icons.remove_rounded,
                    color: AppTheme.textHi, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle button for the gyroscope "air mouse". While active, tilting the
/// phone moves the pointer (real cursor on CVTE, DPAD steps on Android TV).
/// Glows blue and shows a "3D rotation" icon while running.
class _AirMouseButton extends StatefulWidget {
  final AtvController c;
  final double size;
  const _AirMouseButton({required this.c, required this.size});

  @override
  State<_AirMouseButton> createState() => _AirMouseButtonState();
}

class _AirMouseButtonState extends State<_AirMouseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool get _active => widget.c.airMouseActive;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    Haptics.confirm();
    if (_active) {
      widget.c.stopAirMouse();
    } else {
      widget.c.startAirMouse();
    }
  }

  /// Keeps the pulse animation in sync with the controller's actual state —
  /// important because voice search can stop the air mouse out from under us.
  void _syncPulse(bool active) {
    if (active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!active && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    // Watch the real flag so the button reflects external stops (e.g. voice).
    final active =
        context.select<AtvController, bool>((c) => c.airMouseActive);
    _syncPulse(active);
    return Semantics(
      button: true,
      label: 'Air mouse',
      toggled: _active,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glow = _active ? AppTheme.accent : AppTheme.textMid;
            final pulse = _active ? (0.4 + _pulse.value * 0.5) : 0.0;
            return Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _active
                    ? AppTheme.accentGradient
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
                      ),
                border: Border.all(color: AppTheme.glassStroke, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: pulse),
                    blurRadius: _active ? 22 : 0,
                    spreadRadius: _active ? _pulse.value * 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.threed_rotation_rounded,
                size: s * 0.46,
                color: _active ? Colors.white : AppTheme.textHi,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bottom sheet listing the apps installed on the connected Roku, fetched live
/// from the device. Tapping one launches it on the TV. Icons are served by the
/// Roku itself (`/query/icon/<id>`).
class _RokuAppsSheet extends StatefulWidget {
  final AtvController c;
  const _RokuAppsSheet({required this.c});

  @override
  State<_RokuAppsSheet> createState() => _RokuAppsSheetState();
}

class _RokuAppsSheetState extends State<_RokuAppsSheet> {
  late Future<List<RokuApp>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.c.rokuApps();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.c.rokuTarget;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scroll) => GlassPanel(
        radius: AppTheme.rLg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.glassStroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(S.of(context).apps,
                style: const TextStyle(
                    color: AppTheme.textHi,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<RokuApp>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  final apps = snap.data ?? const [];
                  if (apps.isEmpty) {
                    return Center(
                      child: Text(S.of(context).noTvs,
                          style: const TextStyle(color: AppTheme.textMid)),
                    );
                  }
                  return GridView.builder(
                    controller: scroll,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (context, i) {
                      final app = apps[i];
                      return Pressable(
                        onTap: () {
                          widget.c.launchApp(app.id);
                          Navigator.pop(context);
                        },
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.rSm),
                                child: target == null
                                    ? const ColoredBox(
                                        color: AppTheme.surface)
                                    : Image.network(
                                        app.iconUrl(target.$1, target.$2),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, e, s) =>
                                            const ColoredBox(
                                          color: AppTheme.surface,
                                          child: Icon(
                                              Icons.tv_rounded,
                                              color: AppTheme.textMid),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textMid, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
