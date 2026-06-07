import 'dart:convert';

/// What kind of device this is. Drives which control panel the UI shows.
enum ApplianceKind {
  airConditioner,
  fan,
  tv,
  light,
  radio,
  dvd,
  setTopBox,
  projector,
  soundbar,
  heater,
  generic,
}

extension ApplianceKindControl on ApplianceKind {
  /// True for kinds the user drives with momentary key presses (no persisted
  /// state model) — they route through `sendDeviceKey`.
  bool get isKeyBased => switch (this) {
        ApplianceKind.airConditioner ||
        ApplianceKind.fan ||
        ApplianceKind.light ||
        ApplianceKind.heater =>
          false,
        ApplianceKind.tv ||
        ApplianceKind.radio ||
        ApplianceKind.dvd ||
        ApplianceKind.setTopBox ||
        ApplianceKind.projector ||
        ApplianceKind.soundbar ||
        ApplianceKind.generic =>
          true,
      };
}

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

/// The full desired state of a standing/ceiling fan. Like an AC, an IR fan is
/// stateful in spirit but its remote is key-based; we keep a small model so the
/// panel reopens where the user left it and the Wi-Fi command is complete.
class FanState {
  final bool power;
  final int speed; // 1..maxSpeed
  final bool oscillate;

  const FanState({
    this.power = false,
    this.speed = 1,
    this.oscillate = false,
  });

  static const int minSpeed = 1;
  static const int maxSpeed = 3;

  FanState copyWith({bool? power, int? speed, bool? oscillate}) => FanState(
        power: power ?? this.power,
        speed: (speed ?? this.speed).clamp(minSpeed, maxSpeed),
        oscillate: oscillate ?? this.oscillate,
      );

  Map<String, dynamic> toJson() =>
      {'power': power, 'speed': speed, 'oscillate': oscillate};

  factory FanState.fromJson(Map<String, dynamic> j) => FanState(
        power: j['power'] as bool? ?? false,
        speed: (j['speed'] as int?) ?? 1,
        oscillate: j['oscillate'] as bool? ?? false,
      );
}

/// The desired state of a dimmable light.
class LightState {
  final bool power;
  final int brightness; // 0..100 (%)

  const LightState({this.power = false, this.brightness = 100});

  LightState copyWith({bool? power, int? brightness}) => LightState(
        power: power ?? this.power,
        brightness: (brightness ?? this.brightness).clamp(0, 100),
      );

  Map<String, dynamic> toJson() => {'power': power, 'brightness': brightness};

  factory LightState.fromJson(Map<String, dynamic> j) => LightState(
        power: j['power'] as bool? ?? false,
        brightness: (j['brightness'] as int?) ?? 100,
      );
}

/// The desired state of a space heater: power, a heat level, and oscillation.
class HeaterState {
  final bool power;
  final int level; // 1..maxLevel
  final bool oscillate;

  const HeaterState({
    this.power = false,
    this.level = 1,
    this.oscillate = false,
  });

  static const int minLevel = 1;
  static const int maxLevel = 3;

  HeaterState copyWith({bool? power, int? level, bool? oscillate}) =>
      HeaterState(
        power: power ?? this.power,
        level: (level ?? this.level).clamp(minLevel, maxLevel),
        oscillate: oscillate ?? this.oscillate,
      );

  Map<String, dynamic> toJson() =>
      {'power': power, 'level': level, 'oscillate': oscillate};

  factory HeaterState.fromJson(Map<String, dynamic> j) => HeaterState(
        power: j['power'] as bool? ?? false,
        level: (j['level'] as int?) ?? 1,
        oscillate: j['oscillate'] as bool? ?? false,
      );
}

/// A single momentary key for a key-based remote (TV, radio, DVD, etc.).
/// IR encoders turn one of these into a burst; Wi-Fi devices receive its [id].
enum DeviceKey {
  power,
  volumeUp,
  volumeDown,
  mute,
  channelUp,
  channelDown,
  input,
  menu,
  home,
  back,
  up,
  down,
  left,
  right,
  ok,
  // Fan / light momentary keys (used when a model field isn't a clean fit).
  speedUp,
  speedDown,
  oscillate,
  brightnessUp,
  brightnessDown,
  // Numeric keypad (set-top boxes, DVD menus, radio presets, direct channels).
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
  // Media transport (DVD / Blu-ray / soundbar).
  play,
  pause,
  playPause,
  stop,
  rewind,
  fastForward,
  previous,
  next,
  eject,
  record,
  // Audio / tuner (radio, hi-fi, soundbar).
  presetUp,
  presetDown,
  tuneUp,
  tuneDown,
  bassUp,
  bassDown,
  // Heater / projector extras.
  tempUp,
  tempDown,
  focusNear,
  focusFar,
}

extension DeviceKeyInfo on DeviceKey {
  String get id => name;

  /// The DeviceKey for digit [n] (0..9).
  static DeviceKey digit(int n) => switch (n) {
        0 => DeviceKey.digit0,
        1 => DeviceKey.digit1,
        2 => DeviceKey.digit2,
        3 => DeviceKey.digit3,
        4 => DeviceKey.digit4,
        5 => DeviceKey.digit5,
        6 => DeviceKey.digit6,
        7 => DeviceKey.digit7,
        8 => DeviceKey.digit8,
        _ => DeviceKey.digit9,
      };
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

  /// Last known fan state (for [ApplianceKind.fan]). Default for other kinds.
  final FanState fanState;

  /// Last known light state (for [ApplianceKind.light]). Default otherwise.
  final LightState lightState;

  /// Last known heater state (for [ApplianceKind.heater]). Default otherwise.
  final HeaterState heaterState;

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
    this.fanState = const FanState(),
    this.lightState = const LightState(),
    this.heaterState = const HeaterState(),
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
    FanState? fanState,
    LightState? lightState,
    HeaterState? heaterState,
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
        fanState: fanState ?? this.fanState,
        lightState: lightState ?? this.lightState,
        heaterState: heaterState ?? this.heaterState,
        lastUsed: lastUsed ?? this.lastUsed,
        secret: secret ?? this.secret,
      );

  Appliance withSecret(String s) => copyWith(secret: s);

  bool get needsSecret => transport != ApplianceTransport.builtinIr;

  /// Whether this appliance is currently on, across kinds. Key-based kinds
  /// (tv, radio, dvd, etc.) have no persisted power state, so they report false.
  bool get isOn => switch (kind) {
        ApplianceKind.airConditioner => acState.power,
        ApplianceKind.fan => fanState.power,
        ApplianceKind.light => lightState.power,
        ApplianceKind.heater => heaterState.power,
        ApplianceKind.tv ||
        ApplianceKind.radio ||
        ApplianceKind.dvd ||
        ApplianceKind.setTopBox ||
        ApplianceKind.projector ||
        ApplianceKind.soundbar ||
        ApplianceKind.generic =>
          false,
      };

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
        'fanState': fanState.toJson(),
        'lightState': lightState.toJson(),
        'heaterState': heaterState.toJson(),
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
        fanState: j['fanState'] is Map<String, dynamic>
            ? FanState.fromJson(j['fanState'] as Map<String, dynamic>)
            : const FanState(),
        lightState: j['lightState'] is Map<String, dynamic>
            ? LightState.fromJson(j['lightState'] as Map<String, dynamic>)
            : const LightState(),
        heaterState: j['heaterState'] is Map<String, dynamic>
            ? HeaterState.fromJson(j['heaterState'] as Map<String, dynamic>)
            : const HeaterState(),
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
