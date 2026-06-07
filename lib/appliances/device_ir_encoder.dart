import 'appliance.dart';
import 'ir_protocols.dart';

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

/// A key-based encoder that maps each [DeviceKey] to a closure building the raw
/// burst with a real protocol (Samsung32, SIRC, Kaseikyo, RC5/6, Sharp,
/// extended-NEC). Lets brand encoders carry their own carrier + framing while
/// sharing the table-lookup shape of [_NecTableEncoder].
class _ProtoEncoder extends DeviceIrEncoder {
  @override
  final String brandId;
  @override
  final String displayName;
  @override
  final ApplianceKind kind;
  @override
  final int carrierHz;

  final Map<DeviceKey, List<int> Function()> builders;

  _ProtoEncoder({
    required this.brandId,
    required this.displayName,
    required this.kind,
    required this.carrierHz,
    required this.builders,
  });

  @override
  List<int>? encode(DeviceKey key) => builders[key]?.call();
}

// ---------------------------------------------------------------------------
// Real per-brand TV/AV command tables (verified — see
// docs/ir_protocols_research.md). Codes sourced from IRremoteESP8266 / IRDB /
// LIRC. Where a brand uses generic NEC, it stays a [_NecTableEncoder].
// ---------------------------------------------------------------------------

/// Builds a Samsung32 encoder from a customer byte + key→command table.
_ProtoEncoder _samsung(
        String id, String name, ApplianceKind kind, int customer,
        {required Map<DeviceKey, int> cmds}) =>
    _ProtoEncoder(
      brandId: id,
      displayName: name,
      kind: kind,
      carrierHz: SamsungProtocol.carrierHz,
      builders: {
        for (final e in cmds.entries)
          e.key: () => SamsungProtocol.frame(customer, e.value),
      },
    );

/// Builds a Sony SIRC encoder (device address + bit width) from a table.
_ProtoEncoder _sony(String id, String name, ApplianceKind kind, int address,
        {int bits = 12, required Map<DeviceKey, int> cmds}) =>
    _ProtoEncoder(
      brandId: id,
      displayName: name,
      kind: kind,
      carrierHz: SonyProtocol.carrierHz,
      builders: {
        for (final e in cmds.entries)
          e.key: () => SonyProtocol.frame(e.value, address, bits: bits),
      },
    );

/// Builds a Kaseikyo/Panasonic encoder (device + subdevice) from a table.
_ProtoEncoder _panasonic(
        String id, String name, ApplianceKind kind, int device, int subdevice,
        {required Map<DeviceKey, int> cmds}) =>
    _ProtoEncoder(
      brandId: id,
      displayName: name,
      kind: kind,
      carrierHz: KaseikyoProtocol.carrierHz,
      builders: {
        for (final e in cmds.entries)
          e.key: () => KaseikyoProtocol.frame(
              KaseikyoProtocol.panasonicVendor, device, subdevice, e.value),
      },
    );

/// Builds an extended-NEC encoder (fixed 16-bit address) from a table — used by
/// Hisense/TCL whose address byte is not the simple inverse.
_ProtoEncoder _necExt(
        String id, String name, ApplianceKind kind, int address16,
        {required Map<DeviceKey, int> cmds}) =>
    _ProtoEncoder(
      brandId: id,
      displayName: name,
      kind: kind,
      carrierHz: NecProtocol.carrierHz,
      builders: {
        for (final e in cmds.entries)
          e.key: () => NecProtocol.extended(address16, e.value),
      },
    );

/// Builds a Sharp encoder (5-bit address) from a table.
_ProtoEncoder _sharp(String id, String name, ApplianceKind kind, int address,
        {required Map<DeviceKey, int> cmds}) =>
    _ProtoEncoder(
      brandId: id,
      displayName: name,
      kind: kind,
      carrierHz: SharpProtocol.carrierHz,
      builders: {
        for (final e in cmds.entries)
          e.key: () => SharpProtocol.frame(address, e.value),
      },
    );

/// Builds an RC5 encoder (Philips). Toggle is fixed at 0 — most sets accept a
/// non-toggling repeat for momentary presses.
_ProtoEncoder _rc5(String id, String name, ApplianceKind kind, int address,
        {required Map<DeviceKey, int> cmds}) =>
    _ProtoEncoder(
      brandId: id,
      displayName: name,
      kind: kind,
      carrierHz: Rc5Protocol.carrierHz,
      builders: {
        for (final e in cmds.entries)
          e.key: () => Rc5Protocol.frame(address, e.value),
      },
    );

/// Standard TV button set shared across brands, with each brand's command map.
/// (Kept as inline literals per brand below for clarity over abstraction.)

/// Builds an NEC command map for digits 0..9 starting at [base] (digit n =
/// base + n). Merge into a table with the spread operator.
Map<DeviceKey, int> _digits(int base) => {
      for (var n = 0; n < 10; n++) DeviceKeyInfo.digit(n): base + n,
    };

/// Maps digit keys 0..9 to commands via [cmd] (called with n=0..9). Lets brand
/// tables specify non-contiguous digit codes.
Map<DeviceKey, int> _digitsCmd(int Function(int n) cmd) => {
      for (var n = 0; n < 10; n++) DeviceKeyInfo.digit(n): cmd(n),
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

    // ===================================================================
    // Real per-brand TV encoders (verified protocols + codes).
    // ===================================================================

    // Samsung TV — Samsung32, customer 0x07. Codes from IRDB/IRremoteESP8266.
    _samsung('samsung_tv', 'Samsung TV', ApplianceKind.tv, 0x07, cmds: {
      DeviceKey.power: 0x02,
      DeviceKey.volumeUp: 0x07,
      DeviceKey.volumeDown: 0x0B,
      DeviceKey.mute: 0x0F,
      DeviceKey.channelUp: 0x12,
      DeviceKey.channelDown: 0x10,
      DeviceKey.input: 0x01, // SOURCE
      DeviceKey.menu: 0x1A,
      DeviceKey.home: 0x79,
      DeviceKey.back: 0x58,
      DeviceKey.up: 0x60,
      DeviceKey.down: 0x61,
      DeviceKey.left: 0x65,
      DeviceKey.right: 0x62,
      DeviceKey.ok: 0x68,
      ..._digitsCmd((n) => const [
            0x11, 0x04, 0x05, 0x06, 0x08, 0x09, 0x0A, 0x0C, 0x0D, 0x0E
          ][n]),
    }),

    // LG TV — practical default is NEC32 with address 0x04 / 0x20DF (verified
    // as the safe default for most/older LG sets).
    _necExt('lg_tv', 'LG TV', ApplianceKind.tv, 0x20DF, cmds: {
      DeviceKey.power: 0x08,
      DeviceKey.volumeUp: 0x02,
      DeviceKey.volumeDown: 0x03,
      DeviceKey.mute: 0x09,
      DeviceKey.channelUp: 0x00,
      DeviceKey.channelDown: 0x01,
      DeviceKey.input: 0x0B,
      DeviceKey.menu: 0x43,
      DeviceKey.home: 0x7C,
      DeviceKey.back: 0x28,
      DeviceKey.up: 0x40,
      DeviceKey.down: 0x41,
      DeviceKey.left: 0x07,
      DeviceKey.right: 0x06,
      DeviceKey.ok: 0x44,
      ..._digitsCmd((n) => const [
            0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19
          ][n]),
    }),

    // Sony TV — SIRC 12-bit, device address 1.
    _sony('sony_tv', 'Sony TV', ApplianceKind.tv, 1, bits: 12, cmds: {
      DeviceKey.power: 0x15,
      DeviceKey.volumeUp: 0x12,
      DeviceKey.volumeDown: 0x13,
      DeviceKey.mute: 0x14,
      DeviceKey.channelUp: 0x10,
      DeviceKey.channelDown: 0x11,
      DeviceKey.input: 0x25,
      DeviceKey.menu: 0x60,
      DeviceKey.home: 0x60,
      DeviceKey.back: 0x63,
      DeviceKey.up: 0x74,
      DeviceKey.down: 0x75,
      DeviceKey.left: 0x34,
      DeviceKey.right: 0x33,
      DeviceKey.ok: 0x65,
      ..._digitsCmd((n) => const [
            0x09, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08
          ][n]),
    }),

    // Panasonic TV — Kaseikyo, device 0x00 subdevice 0x20.
    _panasonic('panasonic_tv', 'Panasonic TV', ApplianceKind.tv, 0x00, 0x20,
        cmds: {
          DeviceKey.power: 0x3D,
          DeviceKey.volumeUp: 0x20,
          DeviceKey.volumeDown: 0x21,
          DeviceKey.mute: 0x32,
          DeviceKey.channelUp: 0x34,
          DeviceKey.channelDown: 0x35,
          DeviceKey.input: 0x3A,
          DeviceKey.menu: 0x4A,
          DeviceKey.back: 0x53,
          DeviceKey.up: 0x4A,
          DeviceKey.down: 0x4B,
          DeviceKey.left: 0x4E,
          DeviceKey.right: 0x4F,
          DeviceKey.ok: 0x49,
          ..._digitsCmd((n) => const [
                0x19, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18
              ][n]),
        }),

    // Sharp TV — Sharp 15-bit, address 0x01.
    _sharp('sharp_tv', 'Sharp TV', ApplianceKind.tv, 0x01, cmds: {
      DeviceKey.power: 0x16,
      DeviceKey.volumeUp: 0x14,
      DeviceKey.volumeDown: 0x15,
      DeviceKey.mute: 0x17,
      DeviceKey.channelUp: 0x11,
      DeviceKey.channelDown: 0x12,
      DeviceKey.input: 0x02,
      DeviceKey.menu: 0x38,
      DeviceKey.up: 0x19,
      DeviceKey.down: 0x1A,
      DeviceKey.left: 0x1B,
      DeviceKey.right: 0x1C,
      DeviceKey.ok: 0x18,
    }),

    // Philips TV — RC5, address 0x00.
    _rc5('philips_tv', 'Philips TV', ApplianceKind.tv, 0x00, cmds: {
      DeviceKey.power: 0x0C,
      DeviceKey.volumeUp: 0x10,
      DeviceKey.volumeDown: 0x11,
      DeviceKey.mute: 0x0D,
      DeviceKey.channelUp: 0x20,
      DeviceKey.channelDown: 0x21,
      DeviceKey.menu: 0x52,
      DeviceKey.up: 0x55,
      DeviceKey.down: 0x54,
      DeviceKey.left: 0x56,
      DeviceKey.right: 0x57,
      DeviceKey.ok: 0x53,
      ..._digitsCmd((n) => n), // RC5 digits are 0x00..0x09
    }),

    // Hisense TV — extended NEC, fixed address 0x00FD (codes not inverted).
    _necExt('hisense_tv', 'Hisense TV', ApplianceKind.tv, 0x00FD, cmds: {
      DeviceKey.power: 0xB0,
      DeviceKey.volumeUp: 0x40,
      DeviceKey.volumeDown: 0xC0,
      DeviceKey.mute: 0x90,
      DeviceKey.channelUp: 0x20,
      DeviceKey.channelDown: 0xA0,
      DeviceKey.input: 0x70,
      DeviceKey.menu: 0x88,
      DeviceKey.home: 0x18,
      DeviceKey.back: 0x68,
      DeviceKey.up: 0x10,
      DeviceKey.down: 0x30,
      DeviceKey.left: 0x28,
      DeviceKey.right: 0xE0,
      DeviceKey.ok: 0xD0,
    }),

    // TCL TV (modern) — extended NEC, fixed address 0x57E3.
    _necExt('tcl_tv', 'TCL TV', ApplianceKind.tv, 0x57E3, cmds: {
      DeviceKey.power: 0x14,
      DeviceKey.volumeUp: 0x46,
      DeviceKey.volumeDown: 0x44,
      DeviceKey.mute: 0x16,
      DeviceKey.channelUp: 0x40,
      DeviceKey.channelDown: 0x42,
      DeviceKey.input: 0x50,
      DeviceKey.menu: 0x53,
      DeviceKey.home: 0x4F,
      DeviceKey.back: 0x1D,
      DeviceKey.up: 0x06,
      DeviceKey.down: 0x4A,
      DeviceKey.left: 0x0A,
      DeviceKey.right: 0x4E,
      DeviceKey.ok: 0x02,
    }),
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
