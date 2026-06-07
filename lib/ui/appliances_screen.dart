import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../appliances/ac_ir_encoder.dart';
import '../appliances/appliance.dart';
import '../appliances/appliance_controller.dart';
import '../i18n/strings.dart';
import 'theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass.dart';

/// Lists the user's saved appliances (ACs etc.) and opens their control panel.
class AppliancesScreen extends StatelessWidget {
  const AppliancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ApplianceController>();
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 16, 6),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: DirIcons.chevronBack(context),
                      size: 42,
                      iconSize: 26,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.appliances,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textHi,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: c.appliances.isEmpty
                    ? _empty(context, s)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                        children: [
                          for (final a in c.appliances)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ApplianceCard(appliance: a),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: GradientButton(
                  label: s.addAppliance,
                  icon: Icons.add_rounded,
                  onTap: () => _openAddFlow(context, c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, S s) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ac_unit_rounded, size: 56, color: AppTheme.textLo),
            const SizedBox(height: 16),
            Text(s.noAppliances,
                style: const TextStyle(color: AppTheme.textMid, fontSize: 15)),
          ],
        ),
      );
}

void _openAddFlow(BuildContext context, ApplianceController c) {
  Haptics.tap();
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AddApplianceScreen(controller: c)),
  );
}

class _ApplianceCard extends StatelessWidget {
  final Appliance appliance;
  const _ApplianceCard({required this.appliance});

  @override
  Widget build(BuildContext context) {
    final on = appliance.acState.power;
    return Pressable(
      onTap: () {
        Haptics.tap();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AcPanelScreen(appliance: appliance),
        ));
      },
      child: GlassPanel(
        radius: AppTheme.rMd,
        tint: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? AppTheme.accent.withValues(alpha: 0.18)
                    : AppTheme.bg1,
              ),
              child: Icon(_iconFor(appliance.kind),
                  color: on ? AppTheme.accent : AppTheme.textMid),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appliance.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textHi,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    appliance.kind == ApplianceKind.airConditioner && on
                        ? '${appliance.acState.temp}°  ·  ${appliance.brand}'
                        : (on
                            ? S.of(context).on
                            : S.of(context).off),
                    style: const TextStyle(
                        color: AppTheme.textMid, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textLo,
                textDirection:
                    Directionality.of(context) == TextDirection.rtl
                        ? TextDirection.ltr
                        : TextDirection.rtl),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ApplianceKind k) => switch (k) {
        ApplianceKind.airConditioner => Icons.ac_unit_rounded,
        ApplianceKind.fan => Icons.mode_fan_off_rounded,
        ApplianceKind.tv => Icons.tv_rounded,
        ApplianceKind.light => Icons.lightbulb_outline_rounded,
        ApplianceKind.generic => Icons.devices_other_rounded,
      };
}

// ============================ Add flow ============================

/// Minimal add flow: pick transport, brand, name, and (for Wi-Fi/hub) the
/// host/token, then save. Kept on one screen for simplicity.
class AddApplianceScreen extends StatefulWidget {
  final ApplianceController controller;
  const AddApplianceScreen({super.key, required this.controller});

  @override
  State<AddApplianceScreen> createState() => _AddApplianceScreenState();
}

class _AddApplianceScreenState extends State<AddApplianceScreen> {
  final _name = TextEditingController(text: '');
  final _host = TextEditingController(text: '');
  final _token = TextEditingController(text: '');
  ApplianceTransport _transport = ApplianceTransport.builtinIr;
  String _brand = AcIrProtocols.all.first.brandId;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _token.dispose();
    super.dispose();
  }

  bool get _isWifiOrHub => _transport != ApplianceTransport.builtinIr;

  Future<void> _save() async {
    final s = S.of(context);
    final name = _name.text.trim().isEmpty
        ? s.airConditioner
        : _name.text.trim();
    final a = Appliance(
      id: widget.controller.newId(),
      name: name,
      kind: ApplianceKind.airConditioner,
      transport: _transport,
      brand: _transport == ApplianceTransport.wifi ? 'wifi' : _brand,
      host: _isWifiOrHub ? _host.text.trim() : '',
      port: 0,
      secret: _isWifiOrHub ? _token.text.trim() : '',
    );
    await widget.controller.save(a);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = widget.controller;
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  GlassIconButton(
                    icon: DirIcons.chevronBack(context),
                    size: 42,
                    iconSize: 26,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Text(s.addAppliance,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textHi)),
                ],
              ),
              const SizedBox(height: 20),
              _label(s.connection),
              const SizedBox(height: 8),
              _transportPicker(s, c),
              if (_transport == ApplianceTransport.builtinIr &&
                  !c.hasBuiltinIr) ...[
                const SizedBox(height: 8),
                _warn(s.noIrEmitter),
              ],
              const SizedBox(height: 20),
              if (_transport.isIr) ...[
                _label(s.brand),
                const SizedBox(height: 8),
                _brandPicker(),
                const SizedBox(height: 20),
              ],
              if (_isWifiOrHub) ...[
                _label(s.ipAddress),
                const SizedBox(height: 8),
                _field(_host, '192.168.1.50'),
                const SizedBox(height: 16),
                _label(s.tokenOptional),
                const SizedBox(height: 8),
                _field(_token, '••••••'),
                const SizedBox(height: 20),
              ],
              _label(s.name),
              const SizedBox(height: 8),
              _field(_name, s.airConditioner),
              const SizedBox(height: 28),
              GradientButton(
                label: s.save,
                icon: Icons.check_rounded,
                onTap: _isWifiOrHub && _host.text.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: AppTheme.textMid,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  Widget _warn(String t) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.rSm),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: const TextStyle(color: AppTheme.warning, fontSize: 12)),
          ),
        ]),
      );

  Widget _transportPicker(S s, ApplianceController c) {
    final items = [
      (ApplianceTransport.builtinIr, s.builtinIr, Icons.settings_remote_rounded),
      (ApplianceTransport.irHub, s.irHub, Icons.wifi_tethering_rounded),
      (ApplianceTransport.wifi, s.wifiAppliance, Icons.wifi_rounded),
    ];
    return Column(
      children: [
        for (final (t, label, icon) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _choiceRow(
              label: label,
              icon: icon,
              selected: _transport == t,
              onTap: () => setState(() => _transport = t),
            ),
          ),
      ],
    );
  }

  Widget _brandPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final enc in AcIrProtocols.all)
          _chip(enc.displayName, _brand == enc.brandId,
              () => setState(() => _brand = enc.brandId)),
      ],
    );
  }

  Widget _choiceRow({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.14)
              : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.glassStroke,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? AppTheme.accent : AppTheme.textMid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: selected ? AppTheme.textHi : AppTheme.textMid,
                    fontWeight: FontWeight.w600)),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.accent, size: 20),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rXl),
            gradient: selected ? AppTheme.accentGradient : null,
            color: selected ? null : AppTheme.surface,
            border: Border.all(
                color: selected ? Colors.transparent : AppTheme.glassStroke),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textMid,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      );

  Widget _field(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: const TextStyle(color: AppTheme.textHi),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textLo),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.rSm),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

// ============================ AC control panel ============================

/// The thermostat-style control panel for an air conditioner.
class AcPanelScreen extends StatefulWidget {
  final Appliance appliance;
  const AcPanelScreen({super.key, required this.appliance});

  @override
  State<AcPanelScreen> createState() => _AcPanelScreenState();
}

class _AcPanelScreenState extends State<AcPanelScreen> {
  late AcState _state = widget.appliance.acState;

  ApplianceController get _c =>
      Provider.of<ApplianceController>(context, listen: false);

  Future<void> _apply(AcState next) async {
    setState(() => _state = next);
    Haptics.tap();
    await _c.applyAc(widget.appliance, next);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final on = _state.power;
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 16, 6),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: DirIcons.chevronBack(context),
                      size: 42,
                      iconSize: 26,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.appliance.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textHi)),
                    ),
                    _PowerButton(
                      on: on,
                      onTap: () => _apply(_state.copyWith(power: !on)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: on ? 1 : 0.45,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      _TempDial(
                        temp: _state.temp,
                        onChanged: (t) =>
                            _apply(_state.copyWith(temp: t, power: true)),
                      ),
                      const SizedBox(height: 28),
                      _label(s.mode),
                      const SizedBox(height: 10),
                      _modeRow(s),
                      const SizedBox(height: 24),
                      _label(s.fanSpeed),
                      const SizedBox(height: 10),
                      _fanRow(s),
                      const SizedBox(height: 24),
                      _swingRow(s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: AppTheme.textMid,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  Widget _modeRow(S s) {
    final modes = [
      (AcMode.cool, s.modeCool, Icons.ac_unit_rounded),
      (AcMode.heat, s.modeHeat, Icons.wb_sunny_rounded),
      (AcMode.dry, s.modeDry, Icons.water_drop_rounded),
      (AcMode.fan, s.modeFan, Icons.air_rounded),
      (AcMode.auto, s.modeAuto, Icons.autorenew_rounded),
    ];
    return Row(
      children: [
        for (final (m, label, icon) in modes)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _segment(
                label: label,
                icon: icon,
                selected: _state.mode == m,
                onTap: () => _apply(_state.copyWith(mode: m, power: true)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fanRow(S s) {
    final fans = [
      (AcFan.auto, s.fanAuto),
      (AcFan.low, s.fanLow),
      (AcFan.medium, s.fanMedium),
      (AcFan.high, s.fanHigh),
    ];
    return Row(
      children: [
        for (final (f, label) in fans)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _segment(
                label: label,
                selected: _state.fan == f,
                onTap: () => _apply(_state.copyWith(fan: f, power: true)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _swingRow(S s) {
    return Pressable(
      onTap: () => _apply(_state.copyWith(swing: !_state.swing, power: true)),
      child: GlassPanel(
        radius: AppTheme.rMd,
        tint: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          const Icon(Icons.swap_vert_rounded, color: AppTheme.textMid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.swing,
                style: const TextStyle(
                    color: AppTheme.textHi, fontWeight: FontWeight.w600)),
          ),
          _Switch(value: _state.swing),
        ]),
      ),
    );
  }

  Widget _segment({
    required String label,
    IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.rSm),
          gradient: selected ? AppTheme.accentGradient : null,
          color: selected ? null : AppTheme.surface,
          border: Border.all(
              color: selected ? Colors.transparent : AppTheme.glassStroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppTheme.textMid),
              const SizedBox(height: 4),
            ],
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textMid,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TempDial extends StatelessWidget {
  final int temp;
  final ValueChanged<int> onChanged;
  const _TempDial({required this.temp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        radius: AppTheme.rXl,
        tint: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _round(Icons.remove_rounded,
                temp > AcState.minTemp ? () => onChanged(temp - 1) : null),
            const SizedBox(width: 26),
            Column(
              children: [
                Text('$temp°',
                    style: const TextStyle(
                        color: AppTheme.textHi,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        height: 1)),
                Text('${AcState.minTemp}–${AcState.maxTemp}°C',
                    style: const TextStyle(
                        color: AppTheme.textLo, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 26),
            _round(Icons.add_rounded,
                temp < AcState.maxTemp ? () => onChanged(temp + 1) : null),
          ],
        ),
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback? onTap) => Pressable(
        scale: 0.9,
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? AppTheme.bg1 : AppTheme.accent,
          ),
          child: Icon(icon,
              color: onTap == null ? AppTheme.textLo : Colors.white, size: 28),
        ),
      );
}

class _PowerButton extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _PowerButton({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.power_settings_new_rounded,
      size: 46,
      glowColor: on ? AppTheme.success : AppTheme.danger,
      iconColor: on ? AppTheme.success : AppTheme.danger,
      haptic: HapticStyle.power,
      onTap: onTap,
    );
  }
}

class _Switch extends StatelessWidget {
  final bool value;
  const _Switch({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: value ? AppTheme.accent : AppTheme.bg1,
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.all(3),
      child: Container(
        width: 22,
        height: 22,
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      ),
    );
  }
}
