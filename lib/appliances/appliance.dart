import 'dart:convert';

/// What kind of device this is. Drives which control panel the UI shows.
enum ApplianceKind { airConditioner, fan, tv, light, generic }

extension ApplianceKindInfo on ApplianceKind {
  String get id => name;
  static ApplianceKind fromId(String id) => ApplianceKind.values.firstWhere(
        (k) => k.name == id,
        orElse: () => ApplianceKind.generic,
      );
}

/// How commands physically reach the appliance.
enum ApplianceTransport {
  /// The phone's own IR emitter (needs hardware; many phones lack it).
  builtinIr,

  /// An external IR blaster reachable over Wi-Fi (Broadlink / Tuya / etc.) that
  /// re-emits IR codes we send it.
  irHub,

  /// A smart appliance controlled directly over Wi-Fi (HTTP/MQTT), no IR.
  wifi,
}

extension ApplianceTransportInfo on ApplianceTransport {
  String get id => name;
  static ApplianceTransport fromId(String id) =>
      ApplianceTransport.values.firstWhere(
        (t) => t.name == id,
        orElse: () => ApplianceTransport.builtinIr,
      );

  /// True when this transport drives IR codes (built-in emitter or a hub that
  /// re-emits them). Wi-Fi appliances speak their own API instead.
  bool get isIr =>
      this == ApplianceTransport.builtinIr || this == ApplianceTransport.irHub;
}

/// Operating mode of an air conditioner.
enum AcMode { cool, heat, dry, fan, auto }

extension AcModeInfo on AcMode {
  String get id => name;
  static AcMode fromId(String id) => AcMode.values
      .firstWhere((m) => m.name == id, orElse: () => AcMode.cool);
}

/// Fan speed of an air conditioner.
enum AcFan { auto, low, medium, high }

extension AcFanInfo on AcFan {
  String get id => name;
  static AcFan fromId(String id) =>
      AcFan.values.firstWhere((f) => f.name == id, orElse: () => AcFan.auto);
}

/// The full desired state of an air conditioner. IR ACs are stateful: every
/// transmission carries the complete state, so we model it explicitly and the
/// brand encoder turns it into an IR pattern.
class AcState {
  final bool power;
  final int temp; // Celsius
  final AcMode mode;
  final AcFan fan;
  final bool swing;

  const AcState({
    this.power = false,
    this.temp = 24,
    this.mode = AcMode.cool,
    this.fan = AcFan.auto,
    this.swing = false,
  });

  static const int minTemp = 16;
  static const int maxTemp = 30;

  AcState copyWith({
    bool? power,
    int? temp,
    AcMode? mode,
    AcFan? fan,
    bool? swing,
  }) =>
      AcState(
        power: power ?? this.power,
        temp: (temp ?? this.temp).clamp(minTemp, maxTemp),
        mode: mode ?? this.mode,
        fan: fan ?? this.fan,
        swing: swing ?? this.swing,
      );

  Map<String, dynamic> toJson() => {
        'power': power,
        'temp': temp,
        'mode': mode.id,
        'fan': fan.id,
        'swing': swing,
      };

  factory AcState.fromJson(Map<String, dynamic> j) => AcState(
        power: j['power'] as bool? ?? false,
        temp: (j['temp'] as int?) ?? 24,
        mode: AcModeInfo.fromId(j['mode'] as String? ?? 'cool'),
        fan: AcFanInfo.fromId(j['fan'] as String? ?? 'auto'),
        swing: j['swing'] as bool? ?? false,
      );
}

/// A saved appliance: its identity, how to reach it, and its last known state.
/// Non-sensitive metadata is persisted in SharedPreferences; any token/key for
/// a Wi-Fi hub or device lives in secure storage (see ApplianceSecrets).
class Appliance {
  final String id; // stable uuid-ish id we generate at add time
  final String name;
  final ApplianceKind kind;
  final ApplianceTransport transport;

  /// Brand/protocol of the IR codes or Wi-Fi API (e.g. 'samsung', 'gree').
  final String brand;

  /// For irHub / wifi transports: the device or hub address.
  final String host;
  final int port;

  /// Last known AC state (for air conditioners). Persisted so the panel opens
  /// where the user left it. Empty/default for non-AC kinds.
  final AcState acState;

  final int lastUsed;

  /// Secret credential for a Wi-Fi hub/device (token or local key). Empty for
  /// built-in IR. Held in memory after rehydration from secure storage.
  final String secret;

  const Appliance({
    required this.id,
    required this.name,
    required this.kind,
    required this.transport,
    this.brand = '',
    this.host = '',
    this.port = 0,
    this.acState = const AcState(),
    this.lastUsed = 0,
    this.secret = '',
  });

  Appliance copyWith({
    String? name,
    ApplianceKind? kind,
    ApplianceTransport? transport,
    String? brand,
    String? host,
    int? port,
    AcState? acState,
    int? lastUsed,
    String? secret,
  }) =>
      Appliance(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        transport: transport ?? this.transport,
        brand: brand ?? this.brand,
        host: host ?? this.host,
        port: port ?? this.port,
        acState: acState ?? this.acState,
        lastUsed: lastUsed ?? this.lastUsed,
        secret: secret ?? this.secret,
      );

  Appliance withSecret(String s) => copyWith(secret: s);

  bool get needsSecret => transport != ApplianceTransport.builtinIr;

  /// Non-sensitive metadata only (no secret) — for SharedPreferences.
  Map<String, dynamic> toMetadataJson() => {
        'id': id,
        'name': name,
        'kind': kind.id,
        'transport': transport.id,
        'brand': brand,
        'host': host,
        'port': port,
        'acState': acState.toJson(),
        'lastUsed': lastUsed,
      };

  factory Appliance.fromMetadataJson(Map<String, dynamic> j) => Appliance(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Device',
        kind: ApplianceKindInfo.fromId(j['kind'] as String? ?? 'generic'),
        transport:
            ApplianceTransportInfo.fromId(j['transport'] as String? ?? 'builtinIr'),
        brand: (j['brand'] as String?) ?? '',
        host: (j['host'] as String?) ?? '',
        port: (j['port'] as int?) ?? 0,
        acState: j['acState'] is Map<String, dynamic>
            ? AcState.fromJson(j['acState'] as Map<String, dynamic>)
            : const AcState(),
        lastUsed: (j['lastUsed'] as int?) ?? 0,
      );

  static String encodeList(List<Appliance> items) =>
      jsonEncode(items.map((a) => a.toMetadataJson()).toList());

  static List<Appliance> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Appliance.fromMetadataJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
