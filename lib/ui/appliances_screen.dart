import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../appliances/appliance.dart';
import '../appliances/appliance_controller.dart';
import '../appliances/appliance_discovery.dart';
import '../appliances/brand_catalog.dart';
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
    final on = appliance.isOn;
    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Pressable(
        onTap: () {
          Haptics.tap();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _panelFor(appliance),
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
      ),
    );
  }

  void _showOptions(BuildContext context) {
    Haptics.tap();
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassPanel(
            radius: AppTheme.rLg,
            tint: AppTheme.bg1,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.edit_outlined, color: AppTheme.textHi),
                  title: Text(s.rename,
                      style: const TextStyle(color: AppTheme.textHi)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final name =
                        await _promptApplianceName(context, appliance.name);
                    if (name != null && context.mounted) {
                      await context
                          .read<ApplianceController>()
                          .rename(appliance, name);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.danger),
                  title: Text(s.delete,
                      style: const TextStyle(color: AppTheme.danger)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    if (context.mounted) {
                      await context
                          .read<ApplianceController>()
                          .remove(appliance);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ApplianceKind k) => kindIcon(k);
}

/// The icon for an appliance kind, shared by the list card and the pickers.
IconData kindIcon(ApplianceKind k) => switch (k) {
      ApplianceKind.airConditioner => Icons.ac_unit_rounded,
      ApplianceKind.fan => Icons.mode_fan_off_rounded,
      ApplianceKind.tv => Icons.tv_rounded,
      ApplianceKind.light => Icons.lightbulb_outline_rounded,
      ApplianceKind.radio => Icons.radio_rounded,
      ApplianceKind.dvd => Icons.album_rounded,
      ApplianceKind.setTopBox => Icons.settings_input_hdmi_rounded,
      ApplianceKind.projector => Icons.video_camera_back_rounded,
      ApplianceKind.soundbar => Icons.speaker_rounded,
      ApplianceKind.heater => Icons.local_fire_department_rounded,
      ApplianceKind.generic => Icons.devices_other_rounded,
    };

/// The localized display label for an appliance kind.
String kindLabel(S s, ApplianceKind k) => switch (k) {
      ApplianceKind.airConditioner => s.airConditioner,
      ApplianceKind.fan => s.fan,
      ApplianceKind.tv => s.television,
      ApplianceKind.light => s.light,
      ApplianceKind.radio => s.radio,
      ApplianceKind.dvd => s.dvd,
      ApplianceKind.setTopBox => s.setTopBox,
      ApplianceKind.projector => s.projector,
      ApplianceKind.soundbar => s.soundbar,
      ApplianceKind.heater => s.heater,
      ApplianceKind.generic => s.genericDevice,
    };

/// Routes an appliance to the tailored control panel for its kind.
Widget _panelFor(Appliance a) {
  switch (a.kind) {
    case ApplianceKind.airConditioner:
      return AcPanelScreen(appliance: a);
    case ApplianceKind.fan:
      return FanPanelScreen(appliance: a);
    case ApplianceKind.tv:
      return TvPanelScreen(appliance: a);
    case ApplianceKind.light:
      return LightPanelScreen(appliance: a);
    case ApplianceKind.radio:
    case ApplianceKind.soundbar:
      return AudioPanelScreen(appliance: a);
    case ApplianceKind.dvd:
      return MediaPanelScreen(appliance: a);
    case ApplianceKind.setTopBox:
      return SetTopBoxPanelScreen(appliance: a);
    case ApplianceKind.projector:
      return ProjectorPanelScreen(appliance: a);
    case ApplianceKind.heater:
      return HeaterPanelScreen(appliance: a);
    case ApplianceKind.generic:
      return GenericPanelScreen(appliance: a);
  }
}

/// Shows a transient "couldn't reach the device" message. Used when an
/// appliance command (IR send / Wi-Fi request) comes back unsuccessful.
void _showSendError(BuildContext context) {
  Haptics.heavy();
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.surface,
      content: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppTheme.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(S.of(context).commandFailed,
              style: const TextStyle(color: AppTheme.textHi)),
        ),
      ]),
    ));
}

/// Fire-and-forget a key-based command, surfacing a snackbar if it fails.
void _sendKeyWithFeedback(BuildContext context, Appliance a, DeviceKey key) {
  Haptics.tap();
  context.read<ApplianceController>().sendDeviceKey(a, key).then((ok) {
    if (!ok && context.mounted) _showSendError(context);
  });
}

/// Dialog to rename an appliance. Disposes its controller after closing.
Future<String?> _promptApplianceName(BuildContext context, String current) {
  final s = S.of(context);
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rMd)),
      title: Text(s.rename, style: const TextStyle(color: AppTheme.textHi)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        style: const TextStyle(color: AppTheme.textHi),
        decoration: InputDecoration(
          hintText: s.name,
          hintStyle: const TextStyle(color: AppTheme.textLo),
          counterText: '',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textMid),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
          child: Text(s.save),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
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
  final _brandSearch = TextEditingController(text: '');
  ApplianceKind _kind = ApplianceKind.airConditioner;
  ApplianceTransport _transport = ApplianceTransport.builtinIr;
  String _brand = '';

  /// Catalog brands that make the chosen kind (premium→value, then A–Z),
  /// filtered by the brand search box.
  List<Brand> get _brandsForKind {
    final q = _brandSearch.text.trim().toLowerCase();
    final list = BrandCatalog.forKind(_kind);
    if (q.isEmpty) return list;
    return list.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  /// Whether the chosen brand can be controlled over IR for the chosen kind.
  /// Unknown/blank brand ⇒ allow IR (the kind has a generic encoder).
  bool get _brandIrCapable =>
      _brand.isEmpty || BrandCatalog.irCapable(_brand, _kind);

  /// Picks a device kind and resets the brand to the first one valid for it. If
  /// the new kind has no IR-capable brand for the current transport, fall back
  /// to Wi-Fi.
  void _selectKind(ApplianceKind k) {
    setState(() {
      _kind = k;
      _brandSearch.clear();
      final brands = BrandCatalog.forKind(k);
      _brand = brands.isNotEmpty ? brands.first.id : '';
      _coerceTransport();
    });
  }

  /// Picks a brand and, if it's Wi-Fi-only for this kind, forces a Wi-Fi
  /// transport (IR can't reach it).
  void _selectBrand(String id) {
    setState(() {
      _brand = id;
      _coerceTransport();
    });
  }

  /// If the current transport is IR but the brand can't be controlled over IR,
  /// switch to the native Wi-Fi transport.
  void _coerceTransport() {
    if (!_brandIrCapable && _transport.isIr) {
      _transport = ApplianceTransport.wifi;
      _manual = false;
      _scanned = false;
      _found = const [];
      _host.clear();
    }
  }

  /// Default name for the chosen kind (used when the user leaves it blank).
  String _defaultName(S s) =>
      _kind == ApplianceKind.generic ? s.device : kindLabel(s, _kind);

  // Auto-discovery state for Wi-Fi / hub transports.
  bool _scanning = false;
  bool _scanned = false; // a scan has completed at least once
  bool _manual = false; // user chose to enter the address by hand
  List<DiscoveredHub> _found = const [];

  @override
  void initState() {
    super.initState();
    final brands = BrandCatalog.forKind(_kind);
    _brand = brands.isNotEmpty ? brands.first.id : '';
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _token.dispose();
    _brandSearch.dispose();
    super.dispose();
  }

  bool get _isWifiOrHub => _transport != ApplianceTransport.builtinIr;

  /// Picks a transport. For network transports, kick off auto-discovery first;
  /// the manual IP form only appears if discovery finds nothing (or on request).
  void _selectTransport(ApplianceTransport t) {
    setState(() {
      _transport = t;
      _manual = false;
      _scanned = false;
      _found = const [];
      _host.clear();
    });
    if (t != ApplianceTransport.builtinIr) _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    List<DiscoveredHub> hubs = const [];
    try {
      hubs = await ApplianceDiscovery.discover();
    } catch (_) {
      hubs = const [];
    }
    if (!mounted) return;
    // Keep only hubs matching the chosen transport family.
    final filtered =
        hubs.where((h) => h.transport == _transport).toList();
    setState(() {
      _scanning = false;
      _scanned = true;
      _found = filtered;
      // Auto-discovery is the first option; fall back to manual only when the
      // scan comes back empty.
      _manual = filtered.isEmpty;
    });
  }

  void _useHub(DiscoveredHub h) {
    setState(() {
      _host.text = h.host;
      if (h.brand.isNotEmpty) _brand = h.brand;
      _manual = true; // reveal the form pre-filled so the user can add a token
    });
  }

  Future<void> _save() async {
    final s = S.of(context);
    final name =
        _name.text.trim().isEmpty ? _defaultName(s) : _name.text.trim();
    final a = Appliance(
      id: widget.controller.newId(),
      name: name,
      kind: _kind,
      transport: _transport,
      // Store the catalog brand id; the controller resolves it to the right IR
      // encoder (or sends a brand-tagged Wi-Fi command).
      brand: _brand,
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
              _label(s.deviceType),
              const SizedBox(height: 8),
              _kindPicker(s),
              const SizedBox(height: 20),
              _label(s.brand),
              const SizedBox(height: 8),
              _brandPicker(s),
              if (!_brandIrCapable) ...[
                const SizedBox(height: 8),
                _info(s.smartOnlyBrand),
              ],
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
              if (_isWifiOrHub) ...[
                ..._networkSection(s),
                const SizedBox(height: 20),
              ],
              _label(s.name),
              const SizedBox(height: 8),
              _field(_name, _defaultName(s)),
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

  Widget _warn(String t) => _banner(t, AppTheme.warning, Icons.warning_amber_rounded);

  Widget _info(String t) => _banner(t, AppTheme.accent, Icons.info_outline_rounded);

  Widget _banner(String t, Color color, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.rSm),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t, style: TextStyle(color: color, fontSize: 12)),
          ),
        ]),
      );

  Widget _transportPicker(S s, ApplianceController c) {
    // Wi-Fi-only brands (large appliances) can't be reached by IR — only offer
    // the native Wi-Fi transport for them.
    final items = [
      if (_brandIrCapable) ...[
        (ApplianceTransport.builtinIr, s.builtinIr,
            Icons.settings_remote_rounded),
        (ApplianceTransport.irHub, s.irHub, Icons.wifi_tethering_rounded),
      ],
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
              onTap: () => _selectTransport(t),
            ),
          ),
      ],
    );
  }

  Widget _kindPicker(S s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in ApplianceKind.values)
          _chip(kindLabel(s, k), _kind == k, () => _selectKind(k),
              icon: kindIcon(k)),
      ],
    );
  }

  Widget _brandPicker(S s) {
    final brands = _brandsForKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search box appears once the kind has a sizable brand list.
        if (BrandCatalog.forKind(_kind).length > 8) ...[
          TextField(
            controller: _brandSearch,
            style: const TextStyle(color: AppTheme.textHi),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppTheme.textLo),
              hintText: s.searchBrand,
              hintStyle: const TextStyle(color: AppTheme.textLo),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.rSm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (brands.isEmpty)
          _info(s.noBrandsForType)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in brands)
                _chip(b.name, _brand == b.id, () => _selectBrand(b.id)),
            ],
          ),
      ],
    );
  }

  /// Network transports: auto-discovery first, manual entry as a fallback.
  List<Widget> _networkSection(S s) {
    if (_scanning) {
      return [
        _label(s.searchingDevices),
        const SizedBox(height: 12),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];

    // Show discovered hubs (the primary path) when any were found.
    if (_scanned && _found.isNotEmpty) {
      widgets.add(_label(s.foundDevices));
      widgets.add(const SizedBox(height: 8));
      for (final h in _found) {
        final selected = _host.text == h.host;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _choiceRow(
            label: '${h.name}  ·  ${h.host}',
            icon: Icons.wifi_tethering_rounded,
            selected: selected,
            onTap: () => _useHub(h),
          ),
        ));
      }
      widgets.add(const SizedBox(height: 6));
      widgets.add(_linkRow(
        _scanning ? s.searchingDevices : s.rescan,
        Icons.refresh_rounded,
        _scan,
      ));
      widgets.add(_linkRow(s.enterManually, Icons.keyboard_rounded,
          () => setState(() => _manual = true)));
    }

    // Empty-scan note + the manual fallback form.
    if (_scanned && _found.isEmpty && !_manual) {
      widgets.add(_warn(s.noDevicesFound));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_linkRow(s.rescan, Icons.refresh_rounded, _scan));
    }

    if (_manual) {
      if (_found.isNotEmpty) widgets.add(const SizedBox(height: 10));
      widgets.add(_label(s.ipAddress));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_field(_host, '192.168.1.50'));
      widgets.add(const SizedBox(height: 16));
      widgets.add(_label(s.tokenOptional));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_field(_token, '••••••'));
    }

    return widgets;
  }

  Widget _linkRow(String label, IconData icon, VoidCallback onTap) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: AppTheme.accent),
          label: Text(label,
              style: const TextStyle(color: AppTheme.accent)),
        ),
      );

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

  Widget _chip(String label, bool selected, VoidCallback onTap,
          {IconData? icon}) =>
      Pressable(
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : AppTheme.textMid),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textMid,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
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
    final prev = _state;
    setState(() => _state = next);
    Haptics.tap();
    final ok = await _c.applyAc(widget.appliance, next);
    if (!ok && mounted) {
      // The command didn't reach the device — revert the optimistic change so
      // the panel reflects reality, and tell the user.
      setState(() => _state = prev);
      _showSendError(context);
    }
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

// ===================== Shared panel scaffolding =====================

/// Common chrome for the non-AC control panels: a back button, the appliance
/// name, an optional power button in the header, and a dimmable body.
class _PanelScaffold extends StatelessWidget {
  final String title;
  final bool dimWhenOff;
  final bool on;
  final VoidCallback? onPower;
  final Widget child;

  const _PanelScaffold({
    required this.title,
    required this.child,
    this.dimWhenOff = false,
    this.on = true,
    this.onPower,
  });

  @override
  Widget build(BuildContext context) {
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
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textHi)),
                    ),
                    if (onPower != null)
                      _PowerButton(on: on, onTap: onPower!),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: dimWhenOff && !on ? 0.45 : 1,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _panelLabel(String t) => Text(t,
    style: const TextStyle(
        color: AppTheme.textMid, fontSize: 13, fontWeight: FontWeight.w600));

/// A square, glassy control button used across the fan/TV/light/generic panels.
class _PanelButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  const _PanelButton({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      scale: 0.92,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.glassStroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: enabled ? AppTheme.textHi : AppTheme.textLo),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(label!,
                  style: TextStyle(
                      fontSize: 12,
                      color: enabled ? AppTheme.textMid : AppTheme.textLo)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================ Fan panel ============================

/// Control panel for a fan: power, speed steps, and oscillation.
class FanPanelScreen extends StatefulWidget {
  final Appliance appliance;
  const FanPanelScreen({super.key, required this.appliance});

  @override
  State<FanPanelScreen> createState() => _FanPanelScreenState();
}

class _FanPanelScreenState extends State<FanPanelScreen> {
  late FanState _state = widget.appliance.fanState;

  ApplianceController get _c =>
      Provider.of<ApplianceController>(context, listen: false);

  Future<void> _apply(FanState next) async {
    final prev = _state;
    setState(() => _state = next);
    Haptics.tap();
    final ok = await _c.applyFan(widget.appliance, next);
    if (!ok && mounted) {
      setState(() => _state = prev);
      _showSendError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final on = _state.power;
    return _PanelScaffold(
      title: widget.appliance.name,
      dimWhenOff: true,
      on: on,
      onPower: () => _apply(_state.copyWith(power: !on)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: GlassPanel(
              radius: AppTheme.rXl,
              tint: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.mode_fan_off_rounded,
                      size: 64,
                      color: on ? AppTheme.accent : AppTheme.textLo),
                  const SizedBox(height: 8),
                  Text('${s.speed} ${_state.speed}/${FanState.maxSpeed}',
                      style: const TextStyle(
                          color: AppTheme.textHi,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _panelLabel(s.speed),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PanelButton(
                  icon: Icons.remove_rounded,
                  onTap: _state.speed > FanState.minSpeed
                      ? () => _apply(
                          _state.copyWith(speed: _state.speed - 1, power: true))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PanelButton(
                  icon: Icons.add_rounded,
                  onTap: _state.speed < FanState.maxSpeed
                      ? () => _apply(
                          _state.copyWith(speed: _state.speed + 1, power: true))
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Pressable(
            onTap: () =>
                _apply(_state.copyWith(oscillate: !_state.oscillate, power: true)),
            child: GlassPanel(
              radius: AppTheme.rMd,
              tint: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, color: AppTheme.textMid),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.oscillate,
                      style: const TextStyle(
                          color: AppTheme.textHi,
                          fontWeight: FontWeight.w600)),
                ),
                _Switch(value: _state.oscillate),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Light panel ============================

/// Control panel for a dimmable light: power and brightness.
class LightPanelScreen extends StatefulWidget {
  final Appliance appliance;
  const LightPanelScreen({super.key, required this.appliance});

  @override
  State<LightPanelScreen> createState() => _LightPanelScreenState();
}

class _LightPanelScreenState extends State<LightPanelScreen> {
  late LightState _state = widget.appliance.lightState;

  ApplianceController get _c =>
      Provider.of<ApplianceController>(context, listen: false);

  Future<void> _apply(LightState next) async {
    final prev = _state;
    setState(() => _state = next);
    Haptics.tap();
    final ok = await _c.applyLight(widget.appliance, next);
    if (!ok && mounted) {
      setState(() => _state = prev);
      _showSendError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final on = _state.power;
    return _PanelScaffold(
      title: widget.appliance.name,
      dimWhenOff: true,
      on: on,
      onPower: () => _apply(_state.copyWith(power: !on)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: GlassPanel(
              radius: AppTheme.rXl,
              tint: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.lightbulb_rounded,
                      size: 64,
                      color: on
                          ? AppTheme.accent.withValues(
                              alpha: 0.4 + 0.6 * _state.brightness / 100)
                          : AppTheme.textLo),
                  const SizedBox(height: 8),
                  Text('${_state.brightness}%',
                      style: const TextStyle(
                          color: AppTheme.textHi,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _panelLabel(s.brightness),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.bg1,
              thumbColor: Colors.white,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: _state.brightness.toDouble(),
              min: 0,
              max: 100,
              divisions: 10,
              label: '${_state.brightness}%',
              onChanged: (v) => _apply(
                  _state.copyWith(brightness: v.round(), power: true)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ TV panel ============================

/// Control panel for a TV: power, volume, channel, input, and a D-pad. Each
/// button sends a single momentary IR/Wi-Fi key (TVs are not stateful here).
class TvPanelScreen extends StatelessWidget {
  final Appliance appliance;
  const TvPanelScreen({super.key, required this.appliance});

  void _key(BuildContext context, DeviceKey k) {
    _sendKeyWithFeedback(context, appliance, k);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelScaffold(
      title: appliance.name,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(
            children: [
              Expanded(
                  child: _PanelButton(
                      icon: Icons.power_settings_new_rounded,
                      label: s.power,
                      onTap: () => _key(context, DeviceKey.power))),
              const SizedBox(width: 12),
              Expanded(
                  child: _PanelButton(
                      icon: Icons.input_rounded,
                      label: s.input,
                      onTap: () => _key(context, DeviceKey.input))),
              const SizedBox(width: 12),
              Expanded(
                  child: _PanelButton(
                      icon: Icons.volume_off_rounded,
                      label: s.mute,
                      onTap: () => _key(context, DeviceKey.mute))),
            ],
          ),
          const SizedBox(height: 20),
          _dpad(context, s),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _stepper(context, s.volume,
                  DeviceKey.volumeDown, DeviceKey.volumeUp)),
              const SizedBox(width: 12),
              Expanded(child: _stepper(context, s.channel,
                  DeviceKey.channelDown, DeviceKey.channelUp)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _PanelButton(
                      icon: Icons.menu_rounded,
                      label: s.menu,
                      onTap: () => _key(context, DeviceKey.menu))),
              const SizedBox(width: 12),
              Expanded(
                  child: _PanelButton(
                      icon: Icons.home_rounded,
                      label: s.home,
                      onTap: () => _key(context, DeviceKey.home))),
              const SizedBox(width: 12),
              Expanded(
                  child: _PanelButton(
                      icon: DirIcons.chevronBack(context),
                      label: s.back,
                      onTap: () => _key(context, DeviceKey.back))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dpad(BuildContext context, S s) {
    return Center(
      child: GlassPanel(
        radius: AppTheme.rXl,
        tint: AppTheme.surface,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                  alignment: Alignment.topCenter,
                  child: _arrow(context, Icons.keyboard_arrow_up_rounded,
                      DeviceKey.up)),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: _arrow(context, Icons.keyboard_arrow_down_rounded,
                      DeviceKey.down)),
              Align(
                  alignment: Alignment.centerLeft,
                  child: _arrow(context, Icons.keyboard_arrow_left_rounded,
                      DeviceKey.left)),
              Align(
                  alignment: Alignment.centerRight,
                  child: _arrow(context, Icons.keyboard_arrow_right_rounded,
                      DeviceKey.right)),
              Pressable(
                scale: 0.9,
                onTap: () => _key(context, DeviceKey.ok),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, gradient: AppTheme.accentGradient),
                  alignment: Alignment.center,
                  child: Text(s.ok,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(BuildContext context, IconData icon, DeviceKey k) => Pressable(
        scale: 0.85,
        onTap: () => _key(context, k),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: AppTheme.textHi, size: 34),
        ),
      );

  Widget _stepper(BuildContext context, String label, DeviceKey down,
      DeviceKey up) {
    return GlassPanel(
      radius: AppTheme.rMd,
      tint: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Pressable(
            scale: 0.9,
            onTap: () => _key(context, up),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.add_rounded, color: AppTheme.textHi),
            ),
          ),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Pressable(
            scale: 0.9,
            onTap: () => _key(context, down),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.remove_rounded, color: AppTheme.textHi),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================== Generic panel ==========================

/// Fallback panel for a device we only know how to power on/off plus a few
/// directional keys (used for [ApplianceKind.generic]).
class GenericPanelScreen extends StatelessWidget {
  final Appliance appliance;
  const GenericPanelScreen({super.key, required this.appliance});

  void _key(BuildContext context, DeviceKey k) {
    _sendKeyWithFeedback(context, appliance, k);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelScaffold(
      title: appliance.name,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Center(
            child: Pressable(
              scale: 0.92,
              onTap: () => _key(context, DeviceKey.power),
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: AppTheme.accentGradient),
                alignment: Alignment.center,
                child: const Icon(Icons.power_settings_new_rounded,
                    color: Colors.white, size: 64),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(s.power,
                style: const TextStyle(
                    color: AppTheme.textMid, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ===================== Shared key-based controls =====================

/// A circular D-pad (up/down/left/right + OK) that emits [DeviceKey]s. Shared by
/// the TV, set-top box, and projector panels.
class DpadControl extends StatelessWidget {
  final void Function(DeviceKey) onKey;
  final String okLabel;
  const DpadControl({super.key, required this.onKey, required this.okLabel});

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, DeviceKey k) => Pressable(
          scale: 0.85,
          onTap: () => onKey(k),
          child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: AppTheme.textHi, size: 34)),
        );
    return Center(
      child: GlassPanel(
        radius: AppTheme.rXl,
        tint: AppTheme.surface,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                  alignment: Alignment.topCenter,
                  child:
                      arrow(Icons.keyboard_arrow_up_rounded, DeviceKey.up)),
              Align(
                  alignment: Alignment.bottomCenter,
                  child: arrow(
                      Icons.keyboard_arrow_down_rounded, DeviceKey.down)),
              Align(
                  alignment: Alignment.centerLeft,
                  child: arrow(
                      Icons.keyboard_arrow_left_rounded, DeviceKey.left)),
              Align(
                  alignment: Alignment.centerRight,
                  child: arrow(
                      Icons.keyboard_arrow_right_rounded, DeviceKey.right)),
              Pressable(
                scale: 0.9,
                onTap: () => onKey(DeviceKey.ok),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient),
                  alignment: Alignment.center,
                  child: Text(okLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 3×4 numeric keypad (1-9, 0) that emits digit [DeviceKey]s. Shared by the
/// set-top box and DVD panels.
class KeypadControl extends StatelessWidget {
  final void Function(DeviceKey) onKey;
  const KeypadControl({super.key, required this.onKey});

  @override
  Widget build(BuildContext context) {
    Widget digit(int n) => Pressable(
          scale: 0.9,
          onTap: () => onKey(DeviceKeyInfo.digit(n)),
          child: Container(
            margin: const EdgeInsets.all(4),
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.rMd),
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.glassStroke),
            ),
            alignment: Alignment.center,
            child: Text('$n',
                style: const TextStyle(
                    color: AppTheme.textHi,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ),
        );
    Widget row(List<int> ns) => Row(
          children: [for (final n in ns) Expanded(child: digit(n))],
        );
    return Column(
      children: [
        row([1, 2, 3]),
        row([4, 5, 6]),
        row([7, 8, 9]),
        Row(children: [
          const Expanded(child: SizedBox()),
          Expanded(child: digit(0)),
          const Expanded(child: SizedBox()),
        ]),
      ],
    );
  }
}

/// A vertical +/- stepper around a label that emits up/down [DeviceKey]s.
/// Shared by the TV/STB/audio panels for volume, channel, etc.
class KeyStepper extends StatelessWidget {
  final String label;
  final DeviceKey down;
  final DeviceKey up;
  final void Function(DeviceKey) onKey;
  const KeyStepper(
      {super.key,
      required this.label,
      required this.down,
      required this.up,
      required this.onKey});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, DeviceKey k) => Pressable(
          scale: 0.9,
          onTap: () => onKey(k),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppTheme.textHi),
          ),
        );
    return GlassPanel(
      radius: AppTheme.rMd,
      tint: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          btn(Icons.add_rounded, up),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          btn(Icons.remove_rounded, down),
        ],
      ),
    );
  }
}

// ===================== Audio panel (radio / soundbar) =====================

/// A volume/source/mute remote with presets (radio) or bass (soundbar) and
/// media transport. Used for [ApplianceKind.radio] and [ApplianceKind.soundbar].
class AudioPanelScreen extends StatelessWidget {
  final Appliance appliance;
  const AudioPanelScreen({super.key, required this.appliance});

  bool get _isRadio => appliance.kind == ApplianceKind.radio;

  void _key(BuildContext context, DeviceKey k) {
    _sendKeyWithFeedback(context, appliance, k);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelScaffold(
      title: appliance.name,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.power_settings_new_rounded,
                    label: s.power,
                    onTap: () => _key(context, DeviceKey.power))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.input_rounded,
                    label: s.sourceInput,
                    onTap: () => _key(context, DeviceKey.input))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.volume_off_rounded,
                    label: s.mute,
                    onTap: () => _key(context, DeviceKey.mute))),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: KeyStepper(
                    label: s.volume,
                    down: DeviceKey.volumeDown,
                    up: DeviceKey.volumeUp,
                    onKey: (k) => _key(context, k))),
            const SizedBox(width: 12),
            Expanded(
                child: _isRadio
                    ? KeyStepper(
                        label: s.preset,
                        down: DeviceKey.presetDown,
                        up: DeviceKey.presetUp,
                        onKey: (k) => _key(context, k))
                    : KeyStepper(
                        label: s.bass,
                        down: DeviceKey.bassDown,
                        up: DeviceKey.bassUp,
                        onKey: (k) => _key(context, k))),
            if (_isRadio) ...[
              const SizedBox(width: 12),
              Expanded(
                  child: KeyStepper(
                      label: s.tuning,
                      down: DeviceKey.tuneDown,
                      up: DeviceKey.tuneUp,
                      onKey: (k) => _key(context, k))),
            ],
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: () => _key(context, DeviceKey.previous))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.play_arrow_rounded,
                    onTap: () => _key(context, DeviceKey.playPause))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.skip_next_rounded,
                    onTap: () => _key(context, DeviceKey.next))),
          ]),
          if (_isRadio) ...[
            const SizedBox(height: 20),
            _panelLabel(s.preset),
            const SizedBox(height: 10),
            KeypadControl(onKey: (k) => _key(context, k)),
          ],
        ],
      ),
    );
  }
}

// ===================== Media panel (DVD / Blu-ray) =====================

/// A media-transport remote with a D-pad, menu, numeric keypad, and eject.
/// Used for [ApplianceKind.dvd].
class MediaPanelScreen extends StatelessWidget {
  final Appliance appliance;
  const MediaPanelScreen({super.key, required this.appliance});

  void _key(BuildContext context, DeviceKey k) {
    _sendKeyWithFeedback(context, appliance, k);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelScaffold(
      title: appliance.name,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.power_settings_new_rounded,
                    label: s.power,
                    onTap: () => _key(context, DeviceKey.power))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.menu_rounded,
                    label: s.menu,
                    onTap: () => _key(context, DeviceKey.menu))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.eject_rounded,
                    label: s.eject,
                    onTap: () => _key(context, DeviceKey.eject))),
          ]),
          const SizedBox(height: 20),
          DpadControl(onKey: (k) => _key(context, k), okLabel: s.ok),
          const SizedBox(height: 20),
          // Transport row: rewind, play/pause, stop, fast-forward.
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.fast_rewind_rounded,
                    onTap: () => _key(context, DeviceKey.rewind))),
            const SizedBox(width: 10),
            Expanded(
                child: _PanelButton(
                    icon: Icons.play_arrow_rounded,
                    onTap: () => _key(context, DeviceKey.playPause))),
            const SizedBox(width: 10),
            Expanded(
                child: _PanelButton(
                    icon: Icons.stop_rounded,
                    onTap: () => _key(context, DeviceKey.stop))),
            const SizedBox(width: 10),
            Expanded(
                child: _PanelButton(
                    icon: Icons.fast_forward_rounded,
                    onTap: () => _key(context, DeviceKey.fastForward))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: () => _key(context, DeviceKey.previous))),
            const SizedBox(width: 10),
            Expanded(
                child: _PanelButton(
                    icon: Icons.skip_next_rounded,
                    onTap: () => _key(context, DeviceKey.next))),
          ]),
          const SizedBox(height: 20),
          KeypadControl(onKey: (k) => _key(context, k)),
        ],
      ),
    );
  }
}

// ===================== Set-top box panel =====================

/// A cable/satellite receiver remote: power, channel/volume, D-pad, numpad.
/// Used for [ApplianceKind.setTopBox].
class SetTopBoxPanelScreen extends StatelessWidget {
  final Appliance appliance;
  const SetTopBoxPanelScreen({super.key, required this.appliance});

  void _key(BuildContext context, DeviceKey k) {
    _sendKeyWithFeedback(context, appliance, k);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelScaffold(
      title: appliance.name,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.power_settings_new_rounded,
                    label: s.power,
                    onTap: () => _key(context, DeviceKey.power))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.menu_rounded,
                    label: s.menu,
                    onTap: () => _key(context, DeviceKey.menu))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.volume_off_rounded,
                    label: s.mute,
                    onTap: () => _key(context, DeviceKey.mute))),
          ]),
          const SizedBox(height: 20),
          DpadControl(onKey: (k) => _key(context, k), okLabel: s.ok),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: KeyStepper(
                    label: s.channel,
                    down: DeviceKey.channelDown,
                    up: DeviceKey.channelUp,
                    onKey: (k) => _key(context, k))),
            const SizedBox(width: 12),
            Expanded(
                child: KeyStepper(
                    label: s.volume,
                    down: DeviceKey.volumeDown,
                    up: DeviceKey.volumeUp,
                    onKey: (k) => _key(context, k))),
          ]),
          const SizedBox(height: 20),
          KeypadControl(onKey: (k) => _key(context, k)),
        ],
      ),
    );
  }
}

// ===================== Projector panel =====================

/// A projector remote: power, source, menu, D-pad, and focus. Used for
/// [ApplianceKind.projector].
class ProjectorPanelScreen extends StatelessWidget {
  final Appliance appliance;
  const ProjectorPanelScreen({super.key, required this.appliance});

  void _key(BuildContext context, DeviceKey k) {
    _sendKeyWithFeedback(context, appliance, k);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _PanelScaffold(
      title: appliance.name,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.power_settings_new_rounded,
                    label: s.power,
                    onTap: () => _key(context, DeviceKey.power))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.input_rounded,
                    label: s.sourceInput,
                    onTap: () => _key(context, DeviceKey.input))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.menu_rounded,
                    label: s.menu,
                    onTap: () => _key(context, DeviceKey.menu))),
          ]),
          const SizedBox(height: 20),
          DpadControl(onKey: (k) => _key(context, k), okLabel: s.ok),
          const SizedBox(height: 20),
          _panelLabel(s.focus),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _PanelButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _key(context, DeviceKey.focusNear))),
            const SizedBox(width: 12),
            Expanded(
                child: _PanelButton(
                    icon: Icons.add_rounded,
                    onTap: () => _key(context, DeviceKey.focusFar))),
          ]),
        ],
      ),
    );
  }
}

// ===================== Heater panel =====================

/// Control panel for a space heater: power, heat level, and oscillation.
class HeaterPanelScreen extends StatefulWidget {
  final Appliance appliance;
  const HeaterPanelScreen({super.key, required this.appliance});

  @override
  State<HeaterPanelScreen> createState() => _HeaterPanelScreenState();
}

class _HeaterPanelScreenState extends State<HeaterPanelScreen> {
  late HeaterState _state = widget.appliance.heaterState;

  ApplianceController get _c =>
      Provider.of<ApplianceController>(context, listen: false);

  Future<void> _apply(HeaterState next) async {
    final prev = _state;
    setState(() => _state = next);
    Haptics.tap();
    final ok = await _c.applyHeater(widget.appliance, next);
    if (!ok && mounted) {
      setState(() => _state = prev);
      _showSendError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final on = _state.power;
    return _PanelScaffold(
      title: widget.appliance.name,
      dimWhenOff: true,
      on: on,
      onPower: () => _apply(_state.copyWith(power: !on)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: GlassPanel(
              radius: AppTheme.rXl,
              tint: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 64,
                      color: on ? AppTheme.warning : AppTheme.textLo),
                  const SizedBox(height: 8),
                  Text('${s.level} ${_state.level}/${HeaterState.maxLevel}',
                      style: const TextStyle(
                          color: AppTheme.textHi,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _panelLabel(s.level),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _PanelButton(
                icon: Icons.remove_rounded,
                onTap: _state.level > HeaterState.minLevel
                    ? () => _apply(
                        _state.copyWith(level: _state.level - 1, power: true))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PanelButton(
                icon: Icons.add_rounded,
                onTap: _state.level < HeaterState.maxLevel
                    ? () => _apply(
                        _state.copyWith(level: _state.level + 1, power: true))
                    : null,
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Pressable(
            onTap: () => _apply(
                _state.copyWith(oscillate: !_state.oscillate, power: true)),
            child: GlassPanel(
              radius: AppTheme.rMd,
              tint: AppTheme.surface,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, color: AppTheme.textMid),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.oscillate,
                      style: const TextStyle(
                          color: AppTheme.textHi,
                          fontWeight: FontWeight.w600)),
                ),
                _Switch(value: _state.oscillate),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
