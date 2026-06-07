import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../atv/log.dart';
import '../atv/secret_store.dart';
import 'ac_ir_encoder.dart';
import 'appliance.dart';
import 'appliance_transport.dart';
import 'brand_catalog.dart';
import 'device_ir_encoder.dart';

/// Owns the saved appliances and drives control actions across all three
/// transports (built-in IR, Wi-Fi IR hub, native Wi-Fi). Exposed to the UI via
/// [ChangeNotifier], mirroring how [AtvController] handles TVs.
class ApplianceController extends ChangeNotifier {
  static const _kAppliances = 'atv_appliances';

  final SecretStore _secrets;
  ApplianceController({SecretStore? secrets})
      : _secrets = secrets ?? SecretStore();

  List<Appliance> appliances = [];

  /// True once the phone's IR-emitter capability has been probed.
  bool _irProbed = false;
  bool hasBuiltinIr = false;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Loads saved appliances (metadata from prefs, secrets from the keystore).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    appliances = Appliance.decodeList(prefs.getString(_kAppliances));
    for (var i = 0; i < appliances.length; i++) {
      if (appliances[i].needsSecret) {
        final s = await _secrets.readRaw(_secretKey(appliances[i].id));
        if (s != null && s.isNotEmpty) {
          appliances[i] = appliances[i].withSecret(s);
        }
      }
    }
    _sort();
    await probeIr();
    notifyListeners();
  }

  /// Probes whether the phone has a usable IR emitter (cached).
  Future<bool> probeIr() async {
    if (_irProbed) return hasBuiltinIr;
    hasBuiltinIr = await BuiltinIrTransport.hasEmitter();
    _irProbed = true;
    return hasBuiltinIr;
  }

  void _sort() => appliances.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

  String _secretKey(String id) => 'appliance_$id';

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAppliances, Appliance.encodeList(appliances));
    for (final a in appliances) {
      if (a.needsSecret && a.secret.isNotEmpty) {
        await _secrets.writeRaw(_secretKey(a.id), a.secret);
      }
    }
  }

  void _upsert(Appliance a) {
    appliances.removeWhere((x) => x.id == a.id);
    appliances.insert(0, a);
    _sort();
  }

  /// Adds (or updates) an appliance and persists it.
  Future<void> save(Appliance a) async {
    _upsert(a.copyWith(lastUsed: _now()));
    await _persist();
    notifyListeners();
  }

  /// Removes an appliance and wipes its stored secret.
  Future<void> remove(Appliance a) async {
    appliances.removeWhere((x) => x.id == a.id);
    await _secrets.deleteRaw(_secretKey(a.id));
    await _persist();
    notifyListeners();
  }

  /// Renames an appliance.
  Future<void> rename(Appliance a, String newName) async {
    final name = newName.trim();
    if (name.isEmpty || name == a.name) return;
    _upsert(a.copyWith(name: name));
    await _persist();
    notifyListeners();
  }

  /// Generates a stable id for a new appliance.
  String newId() => 'app_${_now()}';

  // ---------------- Control ----------------

  /// Resolves the AC IR encoder for [a]. The appliance stores a brand id from
  /// the catalog (e.g. 'lg'); the catalog maps brand+kind to a dedicated or
  /// generic encoder. Falls back to treating `brand` as a direct encoder id
  /// (legacy appliances), then to the generic Gree encoder so AC control still
  /// works for a brand whose dedicated encoder isn't registered yet.
  AcIrEncoder? _acEncoderFor(Appliance a) {
    final encId = BrandCatalog.irEncoderId(a.brand, a.kind);
    return AcIrProtocols.byId(encId ?? a.brand) ??
        AcIrProtocols.byId(a.brand) ??
        AcIrProtocols.byId('gree');
  }

  /// Resolves the key-based device IR encoder for [a] (see [_acEncoderFor]).
  /// Falls back to the kind's generic encoder if the dedicated one is missing.
  DeviceIrEncoder? _deviceEncoderFor(Appliance a) {
    final encId = BrandCatalog.irEncoderId(a.brand, a.kind);
    return DeviceIrProtocols.byId(encId ?? a.brand) ??
        DeviceIrProtocols.byId(a.brand) ??
        DeviceIrProtocols.byId(_genericDeviceEncoderId(a.kind));
  }

  /// The generic key-based encoder id for [kind] (fallback when no dedicated
  /// encoder is registered). Mirrors brand_catalog's generic mapping.
  String _genericDeviceEncoderId(ApplianceKind kind) => switch (kind) {
        ApplianceKind.tv => 'nec_tv',
        ApplianceKind.fan => 'nec_fan',
        ApplianceKind.light => 'nec_light',
        ApplianceKind.radio => 'nec_radio',
        ApplianceKind.dvd => 'nec_dvd',
        ApplianceKind.setTopBox => 'nec_stb',
        ApplianceKind.projector => 'nec_projector',
        ApplianceKind.soundbar => 'nec_soundbar',
        ApplianceKind.heater => 'nec_heater',
        ApplianceKind.airConditioner || ApplianceKind.generic => '',
      };

  /// Applies an AC state to [a]: encodes it for the brand and sends over the
  /// appliance's transport. Persists the new state so the panel reopens there.
  /// Returns true if the command was delivered.
  Future<bool> applyAc(Appliance a, AcState state) async {
    final updated = a.copyWith(acState: state, lastUsed: _now());
    _upsert(updated);
    await _persist();
    notifyListeners();

    final link = ApplianceLink.forAppliance(updated);
    try {
      if (updated.transport == ApplianceTransport.wifi) {
        // Native Wi-Fi AC: send the state as a structured command.
        return await link.sendWifi({
          'type': 'ac',
          'power': state.power,
          'temp': state.temp,
          'mode': state.mode.id,
          'fan': state.fan.id,
          'swing': state.swing,
        });
      }
      // IR transports (built-in emitter or Wi-Fi IR hub): encode + transmit.
      final enc = _acEncoderFor(updated);
      if (enc == null) {
        atvLog('appliance applyAc', 'no encoder for brand ${updated.brand}');
        return false;
      }
      return await link.sendIr(enc.encode(state), enc.carrierHz);
    } finally {
      link.dispose();
    }
  }

  /// Sends a single momentary [key] to a key-based device (TV, or a fan/light
  /// button). Over IR it transmits the brand's NEC code; over Wi-Fi it sends a
  /// `{type: 'key', key: ...}` command. Returns true if delivered. Marks the
  /// appliance as recently used but does not change persisted state.
  Future<bool> sendDeviceKey(Appliance a, DeviceKey key) async {
    _upsert(a.copyWith(lastUsed: _now()));
    await _persist();
    notifyListeners();

    final link = ApplianceLink.forAppliance(a);
    try {
      if (a.transport == ApplianceTransport.wifi) {
        return await link.sendWifi({'type': 'key', 'key': key.id});
      }
      final enc = _deviceEncoderFor(a);
      final pattern = enc?.encode(key);
      if (pattern == null) {
        atvLog('appliance sendDeviceKey',
            'no IR code for ${a.brand}/${key.id}');
        return false;
      }
      return await link.sendIr(pattern, enc!.carrierHz);
    } finally {
      link.dispose();
    }
  }

  /// Applies a fan [state] to [a]. Wi-Fi fans take the whole state in one
  /// command. IR fans are key-based, so we diff against the last state and emit
  /// the matching presses (power toggle, speed steps, oscillate toggle).
  /// Returns true if every required command was delivered.
  Future<bool> applyFan(Appliance a, FanState state) async {
    final prev = a.fanState;
    final updated = a.copyWith(fanState: state, lastUsed: _now());
    _upsert(updated);
    await _persist();
    notifyListeners();

    final link = ApplianceLink.forAppliance(updated);
    try {
      if (updated.transport == ApplianceTransport.wifi) {
        return await link.sendWifi({
          'type': 'fan',
          'power': state.power,
          'speed': state.speed,
          'oscillate': state.oscillate,
        });
      }
      final enc = _deviceEncoderFor(updated);
      if (enc == null) {
        atvLog('appliance applyFan', 'no encoder for ${updated.brand}');
        return false;
      }
      var ok = true;
      Future<void> press(DeviceKey k) async {
        final p = enc.encode(k);
        if (p != null) ok = await link.sendIr(p, enc.carrierHz) && ok;
      }

      if (prev.power != state.power) await press(DeviceKey.power);
      if (state.power) {
        // Step speed from prev to target with up/down presses.
        var diff = state.speed - prev.speed;
        while (diff > 0) {
          await press(DeviceKey.speedUp);
          diff--;
        }
        while (diff < 0) {
          await press(DeviceKey.speedDown);
          diff++;
        }
        if (prev.oscillate != state.oscillate) {
          await press(DeviceKey.oscillate);
        }
      }
      return ok;
    } finally {
      link.dispose();
    }
  }

  /// Applies a light [state] to [a]. Wi-Fi lights take the whole state; IR
  /// lights are key-based — power toggle plus brightness steps (in ~10% units).
  Future<bool> applyLight(Appliance a, LightState state) async {
    final prev = a.lightState;
    final updated = a.copyWith(lightState: state, lastUsed: _now());
    _upsert(updated);
    await _persist();
    notifyListeners();

    final link = ApplianceLink.forAppliance(updated);
    try {
      if (updated.transport == ApplianceTransport.wifi) {
        return await link.sendWifi({
          'type': 'light',
          'power': state.power,
          'brightness': state.brightness,
        });
      }
      final enc = _deviceEncoderFor(updated);
      if (enc == null) {
        atvLog('appliance applyLight', 'no encoder for ${updated.brand}');
        return false;
      }
      var ok = true;
      Future<void> press(DeviceKey k) async {
        final p = enc.encode(k);
        if (p != null) ok = await link.sendIr(p, enc.carrierHz) && ok;
      }

      if (prev.power != state.power) await press(DeviceKey.power);
      if (state.power) {
        // Each brightness press is ~10%; emit the delta in those steps.
        var steps = ((state.brightness - prev.brightness) / 10).round();
        while (steps > 0) {
          await press(DeviceKey.brightnessUp);
          steps--;
        }
        while (steps < 0) {
          await press(DeviceKey.brightnessDown);
          steps++;
        }
      }
      return ok;
    } finally {
      link.dispose();
    }
  }

  /// Applies a heater [state] to [a]. Wi-Fi heaters take the whole state; IR
  /// heaters are key-based — power toggle, heat-level steps, oscillate toggle.
  Future<bool> applyHeater(Appliance a, HeaterState state) async {
    final prev = a.heaterState;
    final updated = a.copyWith(heaterState: state, lastUsed: _now());
    _upsert(updated);
    await _persist();
    notifyListeners();

    final link = ApplianceLink.forAppliance(updated);
    try {
      if (updated.transport == ApplianceTransport.wifi) {
        return await link.sendWifi({
          'type': 'heater',
          'power': state.power,
          'level': state.level,
          'oscillate': state.oscillate,
        });
      }
      final enc = _deviceEncoderFor(updated);
      if (enc == null) {
        atvLog('appliance applyHeater', 'no encoder for ${updated.brand}');
        return false;
      }
      var ok = true;
      Future<void> press(DeviceKey k) async {
        final p = enc.encode(k);
        if (p != null) ok = await link.sendIr(p, enc.carrierHz) && ok;
      }

      if (prev.power != state.power) await press(DeviceKey.power);
      if (state.power) {
        var diff = state.level - prev.level;
        while (diff > 0) {
          await press(DeviceKey.tempUp);
          diff--;
        }
        while (diff < 0) {
          await press(DeviceKey.tempDown);
          diff++;
        }
        if (prev.oscillate != state.oscillate) {
          await press(DeviceKey.oscillate);
        }
      }
      return ok;
    } finally {
      link.dispose();
    }
  }
}
