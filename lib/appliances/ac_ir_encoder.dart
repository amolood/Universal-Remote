import 'appliance.dart';
import 'ac_brand_encoders.dart';

/// Encodes an [AcState] into a raw IR burst pattern (microseconds, alternating
/// mark/space) for a given AC brand/protocol.
///
/// IR air conditioners are STATEFUL: every press transmits the full state
/// (power, temperature, mode, fan), not a single key. Each manufacturer frames
/// those bits differently, so there is one encoder per protocol. The output is
/// fed either to the phone's IR emitter (transmitRaw) or to a Wi-Fi IR hub.
abstract class AcIrEncoder {
  /// Stable id stored on the appliance (e.g. 'gree').
  String get brandId;

  /// Human-facing brand name (e.g. 'Gree / generic').
  String get displayName;

  /// IR carrier frequency in Hz (almost always 38000).
  int get carrierHz => 38000;

  /// Builds the microsecond mark/space pattern for [state].
  List<int> encode(AcState state);
}

/// Registry of the built-in AC protocols. Start small; add encoders over time.
class AcIrProtocols {
  static final List<AcIrEncoder> all = [
    GreeAcEncoder(),
    // Real per-brand stateful encoders (ported from IRremoteESP8266 — see
    // ac_brand_encoders.dart and docs/ir_protocols_research.md).
    CoolixAcEncoder(),
    MideaAcEncoder(),
    DaikinAcEncoder(),
    PanasonicAcAcEncoder(),
    ToshibaAcAcEncoder(),
    HitachiAcAcEncoder(),
    LgAcAcEncoder(),
    SamsungAcAcEncoder(),
    HaierAcAcEncoder(),
    KelonAcEncoder(),
    Tcl112AcAcEncoder(),
    ElectraAcAcEncoder(),
    WhirlpoolAcAcEncoder(),
    SharpAcAcEncoder(),
  ];

  static AcIrEncoder? byId(String id) {
    for (final e in all) {
      if (e.brandId == id) return e;
    }
    return null;
  }
}

/// Gree YAW1F / YB1F2 protocol — used by Gree and many rebadged units. A
/// well-documented 2×35-bit frame, LSB-first, 38kHz.
///
/// Timing (µs): leader 9000/4500, bit mark 620, "0" space 540, "1" space 1600,
/// a fixed 3-bit "010" separator after the first 35 bits, a 19000µs gap, then
/// the second block, ending with a final mark.
class GreeAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'gree';

  @override
  String get displayName => 'Gree / generic';

  @override
  int get carrierHz => 38000;

  static const int _leadMark = 9000;
  static const int _leadSpace = 4500;
  static const int _bitMark = 620;
  static const int _zeroSpace = 540;
  static const int _oneSpace = 1600;
  static const int _midGap = 19000;

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);
    final out = <int>[];

    void addByteRange(int start, int end) {
      for (var bi = start; bi < end; bi++) {
        final b = bytes[bi];
        for (var i = 0; i < 8; i++) {
          out.add(_bitMark);
          out.add(((b >> i) & 1) == 1 ? _oneSpace : _zeroSpace);
        }
      }
    }

    // Block 1: leader + first 4 bytes + the fixed "010" separator + mid-gap.
    out.add(_leadMark);
    out.add(_leadSpace);
    addByteRange(0, 4);
    // 3-bit separator 0,1,0 (LSB-first as marks/spaces).
    for (final bit in [0, 1, 0]) {
      out.add(_bitMark);
      out.add(bit == 1 ? _oneSpace : _zeroSpace);
    }
    out.add(_bitMark);
    out.add(_midGap);

    // Block 2: remaining 4 bytes, then a final stop mark.
    addByteRange(4, 8);
    out.add(_bitMark);
    return out;
  }

  /// Builds the 8 protocol bytes from the desired state. Layout follows the
  /// common Gree YAW1F mapping; byte 0 holds mode/power/fan/swing, byte 1 the
  /// temperature offset, and a checksum nibble in byte 7.
  List<int> _stateBytes(AcState s) {
    final b = List<int>.filled(8, 0);

    // byte0: bits0-2 mode, bit3 power, bits4-5 fan, bit6 swing(auto)
    b[0] = _modeBits(s.mode) & 0x07;
    if (s.power) b[0] |= 1 << 3;
    b[0] |= (_fanBits(s.fan) & 0x03) << 4;
    if (s.swing) b[0] |= 1 << 6;

    // byte1: bits0-3 temperature (T-16). Gree range 16..30.
    final t = s.temp.clamp(16, 30);
    b[1] = (t - 16) & 0x0F;

    // byte2..6: feature/timer bits left at sane defaults (0).
    // byte3 bit2/bit3 are often "turbo/light"; default off.

    // byte7: high nibble = checksum over the low nibbles of all bytes + const.
    final sum = ((b[0] & 0x0F) +
            (b[1] & 0x0F) +
            (b[2] & 0x0F) +
            (b[3] & 0x0F) +
            (b[4] & 0x0F) +
            (b[5] & 0x0F) +
            (b[6] & 0x0F) +
            0x0A) &
        0x0F;
    b[7] = (sum << 4) | (b[7] & 0x0F);
    return b;
  }

  int _modeBits(AcMode m) => switch (m) {
        AcMode.auto => 0,
        AcMode.cool => 1,
        AcMode.dry => 2,
        AcMode.fan => 3,
        AcMode.heat => 4,
      };

  int _fanBits(AcFan f) => switch (f) {
        AcFan.auto => 0,
        AcFan.low => 1,
        AcFan.medium => 2,
        AcFan.high => 3,
      };
}
