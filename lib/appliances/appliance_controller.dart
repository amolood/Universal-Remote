import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../atv/log.dart';
import '../atv/secret_store.dart';
import 'ac_ir_encoder.dart';
import 'appliance.dart';
import 'appliance_transport.dart';

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
      final enc = AcIrProtocols.byId(updated.brand);
      if (enc == null) {
        atvLog('appliance applyAc', 'no encoder for brand ${updated.brand}');
        return false;
      }
      return await link.sendIr(enc.encode(state), enc.carrierHz);
    } finally {
      link.dispose();
    }
  }
}
