import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../atv/atv_controller.dart';
import '../i18n/strings.dart';
import 'appliances_screen.dart';
import 'theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _hostController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _manual = false;
  RemoteProtocol _manualProtocol = RemoteProtocol.googleTv;
  Timer? _rescanTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = context.read<AtvController>();
      c.scan();
      // Auto-refresh discovery every 6s while browsing (skip while pairing).
      _rescanTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted) return;
        if (c.stage == AppStage.pairing || c.scanning) return;
        c.scan();
      });
    });
  }

  @override
  void dispose() {
    _rescanTimer?.cancel();
    _hostController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  /// Tries a direct connect first; falls back to pairing (code screen) only
  /// if the TV doesn't already recognise us.
  Future<void> _selectTv(
    AtvController c,
    String host, {
    String? name,
    RemoteProtocol protocol = RemoteProtocol.googleTv,
    int port = 6466,
    String deviceId = '',
  }) async {
    FocusScope.of(context).unfocus();
    Haptics.heavy();
    try {
      await c.connectOrPair(host,
          name: name, protocol: protocol, port: port, deviceId: deviceId);
      // Stage transition (remote / pairing) is driven by the controller.
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _submitCode(AtvController c) async {
    FocusScope.of(context).unfocus();
    try {
      await c.submitCode(_codeController.text.trim());
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _connectPin(AtvController c) async {
    FocusScope.of(context).unfocus();
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    Haptics.heavy();
    try {
      await c.connectCvtePin(pin);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppTheme.danger.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rSm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AtvController>();
    final scaffold = Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: c.stage == AppStage.pairing
                ? _codeView(c)
                : _discoveryView(c),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        scaffold,
        if (c.approvalPending) const _ApprovalOverlay(),
      ],
    );
  }

  // ---------------- Discovery view ----------------

  Widget _discoveryView(AtvController c) {
    return Column(
      key: const ValueKey('discovery'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).findYourTv,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textHi,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.scanning
                          ? S.of(context).scanning
                          : S.of(context).devicesFoundN(c.discovered.length),
                      style: const TextStyle(
                          color: AppTheme.textMid, fontSize: 14),
                    ),
                  ],
                ),
              ),
              GlassIconButton(
                icon: Icons.ac_unit_rounded,
                size: 48,
                iconSize: 22,
                onTap: () {
                  Haptics.tap();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AppliancesScreen()));
                },
                tooltip: S.of(context).appliances,
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: c.scanning ? Icons.hourglass_top : Icons.refresh,
                size: 48,
                iconSize: 22,
                onTap: () => c.scan(),
              ),
            ],
          ),
        ),
        Expanded(child: _tvLists(c)),
        _manualSection(c),
      ],
    );
  }

  /// Saved TVs first (with an indicator), then newly discovered ones not yet
  /// saved. Empty state shows the radar.
  Widget _tvLists(AtvController c) {
    // A discovered TV is "already saved" if we match it by stable device id
    // (even at a new IP) or, lacking an id, by protocol+host.
    final savedHostKeys =
        c.pairedTvs.map((t) => '${t.protocol}:${t.host}').toSet();
    final savedDeviceKeys = c.pairedTvs
        .where((t) => t.deviceId.isNotEmpty)
        .map((t) => '${t.protocol}:${t.deviceId}')
        .toSet();
    final freshDiscovered = c.discovered
        .where((d) =>
            !savedHostKeys.contains('${d.protocol}:${d.host}') &&
            !(d.deviceId.isNotEmpty &&
                savedDeviceKeys.contains('${d.protocol}:${d.deviceId}')))
        .toList();

    if (c.pairedTvs.isEmpty && freshDiscovered.isEmpty) return _radar(c);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        if (c.pairedTvs.isNotEmpty) ...[
          _sectionLabel(S.of(context).saved),
          ...c.pairedTvs.map((tv) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TvCard(
                  name: tv.name,
                  host: tv.host,
                  protocol: tv.protocol,
                  saved: true,
                  busy: c.busy,
                  onTap: c.busy
                      ? null
                      : () => _selectTv(c, tv.host,
                          name: tv.name,
                          protocol: tv.protocol,
                          port: tv.port,
                          deviceId: tv.deviceId),
                ),
              )),
        ],
        if (freshDiscovered.isNotEmpty) ...[
          _sectionLabel(c.pairedTvs.isEmpty
              ? S.of(context).available
              : S.of(context).otherTvs),
          ...freshDiscovered.map((tv) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TvCard(
                  name: tv.name,
                  host: tv.host,
                  protocol: tv.protocol,
                  saved: false,
                  busy: c.busy,
                  onTap: c.busy
                      ? null
                      : () => _selectTv(c, tv.host,
                          name: tv.name,
                          protocol: tv.protocol,
                          port: tv.port,
                          deviceId: tv.deviceId),
                ),
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
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

  Widget _radar(AtvController c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadarPulse(active: c.scanning),
            const SizedBox(height: 28),
            Text(
              c.scanning ? S.of(context).lookingNearby : S.of(context).noTvs,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textHi,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context).sameWifiHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMid, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualSection(AtvController c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: !_manual
            ? Center(
                child: TextButton.icon(
                  onPressed: () {
                    Haptics.tap();
                    setState(() => _manual = true);
                  },
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                  label: Text(S.of(context).enterIpManually),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMid,
                  ),
                ),
              )
            : GlassPanel(
                radius: AppTheme.rMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _hostController,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(color: AppTheme.textHi),
                      decoration: InputDecoration(
                        labelText: S.of(context).tvIpAddress,
                        hintText: '192.168.1.10',
                        labelStyle: const TextStyle(color: AppTheme.textMid),
                        prefixIcon:
                            const Icon(Icons.tv, color: AppTheme.textMid),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.rSm),
                          borderSide:
                              const BorderSide(color: AppTheme.glassStroke),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.rSm),
                          borderSide:
                              const BorderSide(color: AppTheme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Brand picker — which protocol to use for the IP above.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in const [
                          RemoteProtocol.googleTv,
                          RemoteProtocol.roku,
                          RemoteProtocol.samsung,
                          RemoteProtocol.lg,
                        ])
                          _BrandChip(
                            protocol: p,
                            selected: _manualProtocol == p,
                            onTap: () =>
                                setState(() => _manualProtocol = p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GradientButton(
                      label: '${S.of(context).pair} • ${_manualProtocol.label}',
                      icon: Icons.cast_connected,
                      busy: c.busy,
                      onTap: c.busy
                          ? null
                          : () {
                              final h = _hostController.text.trim();
                              if (h.isNotEmpty) {
                                _selectTv(c, h,
                                    protocol: _manualProtocol,
                                    port: _manualProtocol.defaultPort);
                              }
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        const Expanded(
                            child: Divider(color: AppTheme.glassStroke)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(S.of(context).or,
                              style:
                                  const TextStyle(color: AppTheme.textLo)),
                        ),
                        const Expanded(
                            child: Divider(color: AppTheme.glassStroke)),
                      ]),
                    ),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                          color: AppTheme.textHi, letterSpacing: 2),
                      decoration: InputDecoration(
                        labelText: S.of(context).smartBoardPin,
                        hintText: 'e.g. ABCDEF',
                        labelStyle: const TextStyle(color: AppTheme.textMid),
                        prefixIcon: const Icon(Icons.dialpad_rounded,
                            color: AppTheme.textMid),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.rSm),
                          borderSide:
                              const BorderSide(color: AppTheme.glassStroke),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.rSm),
                          borderSide:
                              const BorderSide(color: AppTheme.accentPink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientButton(
                      label: S.of(context).connectSmartBoard,
                      icon: Icons.connected_tv_rounded,
                      busy: c.busy,
                      onTap: c.busy
                          ? null
                          : () => _connectPin(c),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------------- Code-entry view ----------------

  Widget _codeView(AtvController c) {
    return Center(
      key: const ValueKey('code'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GlassPanel(
            radius: AppTheme.rLg,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                      boxShadow: AppTheme.glow(AppTheme.accent),
                    ),
                    child: const Icon(Icons.password_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  S.of(context).enterPairingCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHi,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context).codeShowingOnTv,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMid),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                    UpperCaseFormatter(),
                  ],
                  style: const TextStyle(
                    fontSize: 34,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHi,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.25),
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
                const SizedBox(height: 22),
                GradientButton(
                  label: S.of(context).pair,
                  icon: Icons.link_rounded,
                  busy: c.busy,
                  onTap: c.busy ? null : () => _submitCode(c),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: c.busy
                      ? null
                      : () {
                          Haptics.tap();
                          c.cancelPairing();
                        },
                  style:
                      TextButton.styleFrom(foregroundColor: AppTheme.textMid),
                  child: Text(S.of(context).cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass card representing one discovered TV.
class _TvCard extends StatelessWidget {
  final String name;
  final String host;
  final RemoteProtocol protocol;
  final bool busy;
  final bool saved;
  final VoidCallback? onTap;

  const _TvCard({
    required this.name,
    required this.host,
    required this.protocol,
    required this.busy,
    required this.onTap,
    this.saved = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: GlassPanel(
        radius: AppTheme.rMd,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.rSm),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x335B8CFF), Color(0x339B6BFF)],
                ),
                border: Border.all(color: AppTheme.glassStroke),
              ),
              child: const Icon(Icons.tv_rounded,
                  color: AppTheme.textHi, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (saved) ...[
                        const Icon(Icons.check_circle_rounded,
                            size: 13, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(S.of(context).paired,
                            style: const TextStyle(
                                color: AppTheme.success, fontSize: 12)),
                        const Text('  •  ',
                            style: TextStyle(color: AppTheme.textLo)),
                      ],
                      Flexible(
                        child: Text(host,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textMid, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ProtocolBadge(protocol: protocol),
                ],
              ),
            ),
            busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x1AFFFFFF),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppTheme.textMid),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing which protocol a TV speaks.
/// Selectable chip for picking a brand/protocol in the manual-entry panel.
class _BrandChip extends StatelessWidget {
  final RemoteProtocol protocol;
  final bool selected;
  final VoidCallback onTap;
  const _BrandChip({
    required this.protocol,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = protocol == RemoteProtocol.googleTv
        ? S.of(context).androidTv
        : protocol.label;
    return GestureDetector(
      onTap: () {
        Haptics.select();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.rXl),
          gradient: selected ? AppTheme.accentGradient : null,
          color: selected ? null : AppTheme.glassTint,
          border: Border.all(
            color: selected ? Colors.transparent : AppTheme.glassStroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textMid,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  final RemoteProtocol protocol;
  const _ProtocolBadge({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (protocol) {
      RemoteProtocol.googleTv => (
          AppTheme.accent,
          Icons.cast_rounded,
          S.of(context).androidTv
        ),
      RemoteProtocol.cvte => (
          AppTheme.accentPink,
          Icons.connected_tv_rounded,
          S.of(context).smartBoard
        ),
      RemoteProtocol.roku => (
          const Color(0xFF6E2EE6), // Roku purple
          Icons.live_tv_rounded,
          'Roku'
        ),
      RemoteProtocol.samsung => (
          const Color(0xFF1428A0), // Samsung blue
          Icons.tv_rounded,
          'Samsung'
        ),
      RemoteProtocol.lg => (
          const Color(0xFFA50034), // LG red
          Icons.tv_rounded,
          'LG'
        ),
      RemoteProtocol.ir => (
          AppTheme.warning,
          Icons.settings_remote_rounded,
          S.of(context).infrared
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A pulsing radar shown while scanning / when empty.
class _RadarPulse extends StatefulWidget {
  final bool active;
  const _RadarPulse({required this.active});

  @override
  State<_RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<_RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active) ...[
                _ring(_c.value),
                _ring((_c.value + 0.5) % 1.0),
              ],
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                  boxShadow: AppTheme.glow(AppTheme.accent, strength: 0.5),
                ),
                child: Icon(
                  widget.active ? Icons.wifi_tethering : Icons.tv_off_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _ring(double t) {
    final v = Curves.easeOut.transform(t);
    return Container(
      width: 84 + v * 76,
      height: 84 + v * 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: (1 - v) * 0.6),
          width: 2,
        ),
      ),
    );
  }
}

/// Full-screen hint shown while a Samsung/LG TV is waiting for the user to
/// accept the on-screen approval prompt during first pairing.
class _ApprovalOverlay extends StatelessWidget {
  const _ApprovalOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: GlassPanel(
            radius: AppTheme.rLg,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tv_rounded,
                    color: AppTheme.accent, size: 46),
                const SizedBox(height: 18),
                Text(
                  S.of(context).approvalTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textHi,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 240,
                  child: Text(
                    S.of(context).approvalBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 22),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Forces typed text to uppercase (hex code display).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
