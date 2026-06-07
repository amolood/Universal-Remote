import 'appliance.dart';

/// Encodes a single momentary [DeviceKey] into a raw IR burst (microseconds,
/// alternating mark/space) for a key-based device — a TV, fan, or light.
///
/// Unlike air conditioners (whose every press carries the whole state, see
/// [AcIrEncoder]), these remotes are key-based: one button = one code. Each
/// encoder maps the keys it supports to an NEC address/command pair; keys it
/// doesn't support return null so the controller can skip them.
abstract class DeviceIrEncoder {
  /// Stable id stored on the appliance (e.g. 'nec_tv').
  String get brandId;

  /// Human-facing name shown in the brand picker.
  String get displayName;

  /// Which appliance kind this encoder drives.
  ApplianceKind get kind;

  /// IR carrier frequency in Hz (NEC is 38kHz).
  int get carrierHz => 38000;

  /// Builds the microsecond mark/space pattern for [key], or null if this
  /// device has no code for that key.
  List<int>? encode(DeviceKey key);
}

/// Standard NEC frame builder shared by the key-based encoders below.
///
/// NEC: a 9000µs leader mark + 4500µs space, then 32 bits LSB-first
/// (address, ~address, command, ~command) where a bit is a 560µs mark followed
/// by a 560µs space for "0" or a 1690µs space for "1", terminated by a final
/// 560µs stop mark.
class _Nec {
  static const int _leadMark = 9000;
  static const int _leadSpace = 4500;
  static const int _bitMark = 560;
  static const int _zeroSpace = 560;
  static const int _oneSpace = 1690;

  /// Encodes an 8-bit [address] + 8-bit [command] into a full NEC burst.
  static List<int> frame(int address, int command) {
    final out = <int>[_leadMark, _leadSpace];
    void addByte(int b) {
      for (var i = 0; i < 8; i++) {
        out.add(_bitMark);
        out.add(((b >> i) & 1) == 1 ? _oneSpace : _zeroSpace);
      }
    }

    addByte(address & 0xFF);
    addByte((~address) & 0xFF);
    addByte(command & 0xFF);
    addByte((~command) & 0xFF);
    out.add(_bitMark); // stop bit
    return out;
  }
}

/// A key-based encoder built from a fixed NEC address + a key→command table.
class _NecTableEncoder extends DeviceIrEncoder {
  @override
  final String brandId;
  @override
  final String displayName;
  @override
  final ApplianceKind kind;

  final int address;
  final Map<DeviceKey, int> commands;

  _NecTableEncoder({
    required this.brandId,
    required this.displayName,
    required this.kind,
    required this.address,
    required this.commands,
  });

  @override
  List<int>? encode(DeviceKey key) {
    final cmd = commands[key];
    if (cmd == null) return null;
    return _Nec.frame(address, cmd);
  }
}

/// Builds an NEC command map for digits 0..9 starting at [base] (digit n =
/// base + n). Merge into a table with the spread operator.
Map<DeviceKey, int> _digits(int base) => {
      for (var n = 0; n < 10; n++) DeviceKeyInfo.digit(n): base + n,
    };

/// Registry of built-in key-based IR protocols (TV, radio, DVD, etc.). One
/// well-documented generic protocol per kind; add more brands over time. The
/// command tables follow widely-cloned generic NEC remotes.
class DeviceIrProtocols {
  static final List<DeviceIrEncoder> all = [
    // Generic NEC TV remote (address 0x04 — common on many no-name TVs).
    _NecTableEncoder(
      brandId: 'nec_tv',
      displayName: 'Generic TV (NEC)',
      kind: ApplianceKind.tv,
      address: 0x04,
      commands: {
        DeviceKey.power: 0x08,
        DeviceKey.volumeUp: 0x02,
        DeviceKey.volumeDown: 0x03,
        DeviceKey.mute: 0x09,
        DeviceKey.channelUp: 0x00,
        DeviceKey.channelDown: 0x01,
        DeviceKey.input: 0x0B,
        DeviceKey.menu: 0x47,
        DeviceKey.home: 0x53,
        DeviceKey.back: 0x0E,
        DeviceKey.up: 0x40,
        DeviceKey.down: 0x41,
        DeviceKey.left: 0x07,
        DeviceKey.right: 0x06,
        DeviceKey.ok: 0x44,
      },
    ),
    // Generic standing/ceiling fan remote (address 0x00).
    _NecTableEncoder(
      brandId: 'nec_fan',
      displayName: 'Generic Fan (NEC)',
      kind: ApplianceKind.fan,
      address: 0x00,
      commands: {
        DeviceKey.power: 0x10,
        DeviceKey.speedUp: 0x11,
        DeviceKey.speedDown: 0x12,
        DeviceKey.oscillate: 0x13,
      },
    ),
    // Generic LED light / bulb remote (address 0x00).
    _NecTableEncoder(
      brandId: 'nec_light',
      displayName: 'Generic Light (NEC)',
      kind: ApplianceKind.light,
      address: 0x00,
      commands: {
        DeviceKey.power: 0x40,
        DeviceKey.brightnessUp: 0x44,
        DeviceKey.brightnessDown: 0x45,
      },
    ),
    // Generic radio / hi-fi tuner remote (address 0x01).
    _NecTableEncoder(
      brandId: 'nec_radio',
      displayName: 'Generic Radio / Hi-Fi (NEC)',
      kind: ApplianceKind.radio,
      address: 0x01,
      commands: {
        DeviceKey.power: 0x0C,
        DeviceKey.volumeUp: 0x10,
        DeviceKey.volumeDown: 0x11,
        DeviceKey.mute: 0x0D,
        DeviceKey.input: 0x38, // source / band
        DeviceKey.presetUp: 0x1E,
        DeviceKey.presetDown: 0x1F,
        DeviceKey.tuneUp: 0x20,
        DeviceKey.tuneDown: 0x21,
        ..._digits(0x00), // presets 0..9 at 0x00..0x09
      },
    ),
    // Generic DVD / Blu-ray remote (address 0x02).
    _NecTableEncoder(
      brandId: 'nec_dvd',
      displayName: 'Generic DVD / Blu-ray (NEC)',
      kind: ApplianceKind.dvd,
      address: 0x02,
      commands: {
        DeviceKey.power: 0x80,
        DeviceKey.playPause: 0x81,
        DeviceKey.play: 0x82,
        DeviceKey.pause: 0x83,
        DeviceKey.stop: 0x84,
        DeviceKey.previous: 0x85,
        DeviceKey.next: 0x86,
        DeviceKey.rewind: 0x87,
        DeviceKey.fastForward: 0x88,
        DeviceKey.eject: 0x89,
        DeviceKey.menu: 0x8A,
        DeviceKey.up: 0x8B,
        DeviceKey.down: 0x8C,
        DeviceKey.left: 0x8D,
        DeviceKey.right: 0x8E,
        DeviceKey.ok: 0x8F,
        DeviceKey.back: 0x90,
        ..._digits(0x10), // 0..9 at 0x10..0x19
      },
    ),
    // Generic set-top box / cable receiver remote (address 0x03).
    _NecTableEncoder(
      brandId: 'nec_stb',
      displayName: 'Generic Set-top Box (NEC)',
      kind: ApplianceKind.setTopBox,
      address: 0x03,
      commands: {
        DeviceKey.power: 0x40,
        DeviceKey.channelUp: 0x41,
        DeviceKey.channelDown: 0x42,
        DeviceKey.volumeUp: 0x43,
        DeviceKey.volumeDown: 0x44,
        DeviceKey.mute: 0x45,
        DeviceKey.menu: 0x46,
        DeviceKey.input: 0x47,
        DeviceKey.up: 0x48,
        DeviceKey.down: 0x49,
        DeviceKey.left: 0x4A,
        DeviceKey.right: 0x4B,
        DeviceKey.ok: 0x4C,
        DeviceKey.back: 0x4D,
        ..._digits(0x10), // 0..9 at 0x10..0x19
      },
    ),
    // Generic projector remote (address 0x05).
    _NecTableEncoder(
      brandId: 'nec_projector',
      displayName: 'Generic Projector (NEC)',
      kind: ApplianceKind.projector,
      address: 0x05,
      commands: {
        DeviceKey.power: 0x00,
        DeviceKey.input: 0x01, // source
        DeviceKey.menu: 0x02,
        DeviceKey.up: 0x03,
        DeviceKey.down: 0x04,
        DeviceKey.left: 0x05,
        DeviceKey.right: 0x06,
        DeviceKey.ok: 0x07,
        DeviceKey.back: 0x08,
        DeviceKey.focusNear: 0x09,
        DeviceKey.focusFar: 0x0A,
      },
    ),
    // Generic soundbar remote (address 0x06).
    _NecTableEncoder(
      brandId: 'nec_soundbar',
      displayName: 'Generic Soundbar (NEC)',
      kind: ApplianceKind.soundbar,
      address: 0x06,
      commands: {
        DeviceKey.power: 0x00,
        DeviceKey.volumeUp: 0x01,
        DeviceKey.volumeDown: 0x02,
        DeviceKey.mute: 0x03,
        DeviceKey.input: 0x04, // source
        DeviceKey.bassUp: 0x05,
        DeviceKey.bassDown: 0x06,
        DeviceKey.playPause: 0x07,
        DeviceKey.previous: 0x08,
        DeviceKey.next: 0x09,
      },
    ),
    // Generic space-heater remote (address 0x07). State-based but key-driven.
    _NecTableEncoder(
      brandId: 'nec_heater',
      displayName: 'Generic Heater (NEC)',
      kind: ApplianceKind.heater,
      address: 0x07,
      commands: {
        DeviceKey.power: 0x00,
        DeviceKey.tempUp: 0x01,
        DeviceKey.tempDown: 0x02,
        DeviceKey.oscillate: 0x03,
      },
    ),
  ];

  /// All encoders that drive [kind].
  static List<DeviceIrEncoder> forKind(ApplianceKind kind) =>
      all.where((e) => e.kind == kind).toList();

  static DeviceIrEncoder? byId(String id) {
    for (final e in all) {
      if (e.brandId == id) return e;
    }
    return null;
  }
}
