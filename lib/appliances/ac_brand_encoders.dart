/// Real stateful air-conditioner IR encoders, ported from IRremoteESP8266
/// (github.com/crankyoldgit/IRremoteESP8266) via a researched + adversarially
/// reviewed spec (docs/ir_protocols_research.md).
///
/// Each class implements [AcIrEncoder]: it translates an [AcState] into the
/// brand's full byte frame + checksum and frames it as IR pulses. Confidence
/// per encoder is noted in its doc comment. These are auto-generated ports;
/// timings/layouts follow the source but real-device accuracy is not
/// guaranteed for every model variant.
library;

import 'ac_ir_encoder.dart';
import 'appliance.dart';
import 'ac_protocols.dart';

/// Coolix 24-bit air-conditioner IR protocol.
///
/// Ported from IRremoteESP8266 `ir_Coolix.cpp` / `ir_Coolix.h`
/// (github.com/crankyoldgit/IRremoteESP8266). Serves Beko, some Kenmore and
/// generic OEM units.
///
/// Coolix is unusual versus the other byte-layout protocols in this app:
///   * The payload is a single 24-bit code (3 bytes), NOT a free byte array
///     with a trailing checksum. The "checksum" is structural: every byte is
///     transmitted normally and then immediately again as its bitwise
///     complement (`byte ^ 0xFF`). So there is no additive/xor checksum field.
///   * Bytes are sent most-significant-byte first, and bits MSB-first within
///     each byte (the opposite of [acFrameLsb], which is LSB-first). We
///     therefore build the burst by hand, reusing only the [AcTiming]
///     constants.
///
/// 24-bit field layout (bit 0 = LSB of the 24-bit value), from ir_Coolix.h:
///   bit  0      : reserved (0)
///   bit  1      : ZoneFollow1
///   bits 2-3    : Mode
///   bits 4-7    : Temp  (encoded via kCoolixTempMap, NOT raw Celsius)
///   bits 8-12   : SensorTemp (5 bits; 0x1F = "ignore")
///   bits 13-15  : Fan
///   bits 16-18  : "Unknown" (preserved from default state = 0b010, NOT 0)
///   bit  19     : ZoneFollow2
///   bits 20-23  : Fixed = 0b1011
///
/// Reference default state: kCoolixDefaultState = 0xB21FC8
/// (Mode=Auto, Temp=25C, SensorTemp=ignore, Fan=Auto0, Fixed=0b1011).

class CoolixAcEncoder implements AcIrEncoder {
  const CoolixAcEncoder();

  @override
  String get brandId => 'coolix';

  @override
  String get displayName => 'Coolix (Beko / generic OEM)';

  @override
  int get carrierHz => 38000;

  // --- Timings (microseconds), from ir_Coolix.cpp -------------------------
  // kCoolixHdrMark 4692, kCoolixHdrSpace 4416, kCoolixBitMark 552,
  // kCoolixOneSpace 1656, kCoolixZeroSpace 552, kCoolixMinGap 5244.
  static const AcTiming _t = AcTiming(
    leadMark: 4692,
    leadSpace: 4416,
    bitMark: 552,
    oneSpace: 1656,
    zeroSpace: 552,
  );
  static const int _minGap = 5244; // kCoolixMinGap (footer space)

  // --- Mode values (ir_Coolix.h), stored in bits 2-3 ----------------------
  static const int _modeCool = 0x0; // kCoolixCool
  static const int _modeDry = 0x1; // kCoolixDry
  static const int _modeAuto = 0x2; // kCoolixAuto
  static const int _modeHeat = 0x3; // kCoolixHeat
  // kCoolixFan (0b100) is synthetic and does not fit the 2-bit field: it is
  // encoded as Dry mode + Temp = kCoolixFanTempCode, exactly like setMode().

  // --- Fan values (ir_Coolix.h), stored in bits 13-15 ---------------------
  static const int _fanMin = 0x4; // kCoolixFanMin  (0b100)
  static const int _fanMed = 0x2; // kCoolixFanMed  (0b010)
  static const int _fanMax = 0x1; // kCoolixFanMax  (0b001)
  static const int _fanAuto = 0x5; // kCoolixFanAuto (0b101)

  // --- Temperature (ir_Coolix.h) ------------------------------------------
  static const int _tempMin = 17; // kCoolixTempMin
  static const int _tempMax = 30; // kCoolixTempMax
  static const int _fanTempCode = 0xE; // kCoolixFanTempCode (0b1110)

  /// kCoolixTempMap: index = (Celsius - 17), value = 4-bit Temp field.
  static const List<int> _tempMap = <int>[
    0x0, // 17C  0b0000
    0x1, // 18C  0b0001
    0x3, // 19C  0b0011
    0x2, // 20C  0b0010
    0x6, // 21C  0b0110
    0x7, // 22C  0b0111
    0x5, // 23C  0b0101
    0x4, // 24C  0b0100
    0xC, // 25C  0b1100
    0xD, // 26C  0b1101
    0x9, // 27C  0b1001
    0x8, // 28C  0b1000
    0xA, // 29C  0b1010
    0xB, // 30C  0b1011
  ];

  static const int _sensorTempIgnore = 0x1F; // kCoolixSensorTempIgnoreCode

  // bits 16-18: "Unknown" 3-bit field. IRremoteESP8266 never clears this; the
  // state is built from setRaw(kCoolixDefaultState)=0xB21FC8 and only the
  // Mode/Temp/Fan/SensorTemp fields are overwritten, so these bits keep the
  // default value 0b010. Zeroing them (as a naive port would) yields byte2
  // 0xB0 instead of the genuine 0xB2 and corrupts every frame + its
  // transmitted complement. We therefore hold this nibble at 0b010.
  static const int _midUnknown = 0x2; // bits 16-18 = 0b010 (from default)
  static const int _fixed = 0xB; // bits 20-23, 0b1011

  // --- Whole-frame command words (ir_Coolix.h) ----------------------------
  // These are complete 24-bit codes, not bit fields. Power is a toggle on real
  // units; IRremoteESP8266 represents "off" as this dedicated command word.
  static const int _cmdOff = 0xB27BE0; // kCoolixOff

  int _modeBits(AcMode mode) {
    switch (mode) {
      case AcMode.cool:
        return _modeCool;
      case AcMode.heat:
        return _modeHeat;
      case AcMode.dry:
        return _modeDry;
      case AcMode.auto:
        return _modeAuto;
      case AcMode.fan:
        // Synthetic fan-only: transmitted as Dry mode + special temp code.
        return _modeDry;
    }
  }

  int _fanBits(AcFan fan) {
    switch (fan) {
      case AcFan.auto:
        return _fanAuto;
      case AcFan.low:
        return _fanMin;
      case AcFan.medium:
        return _fanMed;
      case AcFan.high:
        return _fanMax;
    }
  }

  /// Assembles the 24-bit Coolix code for the given state.
  int _buildCode(AcState state) {
    // App temp range is 16-30C; Coolix supports 17-30C, so clamp.
    final celsius = state.tempIn(_tempMin, _tempMax);

    final int tempField;
    if (state.mode == AcMode.fan) {
      tempField = _fanTempCode; // setMode(Fan) overwrites Temp with this.
    } else {
      tempField = _tempMap[celsius - _tempMin];
    }

    final modeField = _modeBits(state.mode);
    final fanField = _fanBits(state.fan);

    var code = 0;
    code |= (0 & 0x1) << 0; // reserved
    code |= (0 & 0x1) << 1; // ZoneFollow1
    code |= (modeField & 0x3) << 2; // Mode
    code |= (tempField & 0xF) << 4; // Temp
    code |= (_sensorTempIgnore & 0x1F) << 8; // SensorTemp = ignore
    code |= (fanField & 0x7) << 13; // Fan
    code |= (_midUnknown & 0x7) << 16; // bits 16-18 = 0b010 (from default)
    code |= (0 & 0x1) << 19; // ZoneFollow2
    code |= (_fixed & 0xF) << 20; // Fixed = 0b1011
    return code & 0xFFFFFF;

    // NOTE: Swing has no per-state bit in the Coolix 24-bit layout; it is a
    // separate toggle command word (kCoolixSwing = 0xB26BE0). We therefore
    // cannot represent state.swing inside this state frame and leave it out;
    // a swing toggle would need to be sent as its own command word.
  }

  /// Emits one 24-bit Coolix code: MSB byte first, each byte followed by its
  /// 8-bit complement, MSB-first within each byte. Mirrors sendCoolix().
  List<int> _emit(int code) {
    final out = <int>[_t.leadMark, _t.leadSpace];
    for (var shift = 16; shift >= 0; shift -= 8) {
      final segment = (code >> shift) & 0xFF;
      _addByteMsb(out, segment);
      _addByteMsb(out, segment ^ 0xFF);
    }
    out.add(_t.bitMark); // footer mark
    out.add(_minGap); // footer space (min gap)
    return out;
  }

  void _addByteMsb(List<int> out, int b) {
    for (var i = 7; i >= 0; i--) {
      out.add(_t.bitMark);
      out.add(((b >> i) & 1) == 1 ? _t.oneSpace : _t.zeroSpace);
    }
  }

  @override
  List<int> encode(AcState state) {
    // Power is a toggle on real hardware. When the desired state is "off",
    // IRremoteESP8266 sends the dedicated kCoolixOff command word rather than
    // a temp/mode/fan frame.
    final code = state.power ? _buildCode(state) : _cmdOff;
    return _emit(code);
  }
}

/// Midea 48-bit air-conditioner IR protocol.
///
/// Ported from IRremoteESP8266 `ir_Midea.cpp` / `ir_Midea.h`
/// (raw.githubusercontent.com/crankyoldgit/IRremoteESP8266/master/src/ir_Midea.cpp).
/// Serves Midea and Midea clones (Pelonis AC, Electrolux/Frigidaire).
///
/// Wire format: a 6-byte state transmitted MSB-byte-first / MSB-bit-first,
/// immediately followed by an entirely bit-inverted copy of the same 6 bytes
/// (the two halves are separated by [kMideaMinGap]). NEC-like pulse-distance
/// timing built on an 80us tick.
///
/// 48-bit state union (byte 0 = LSB, fields fill each byte from its LSB):
///   Byte 0: Sum (checksum)
///   Byte 1: SensorTemp:7, disableSensor:1
///   Byte 2: pad:1, OffTimer:6, BeepDisable:1
///   Byte 3: Temp:5, useFahrenheit:1, pad:2
///   Byte 4: Mode:3, Fan:2, pad:1, Sleep:1, Power:1
///   Byte 5: Type:3, Header:5
///
/// Default ("on, Auto, FanAuto, 25C") state is 0xA1826FFFFF62, which fixes
/// Header = 0b10100 (20) and Type = Command (1) -> byte5 = 0xA1, and the unused
/// SensorTemp/OffTimer bytes to 0xFF (byte1 = byte2 = 0xFF).
class MideaAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'midea';

  @override
  String get displayName => 'Midea (48-bit)';

  @override
  int get carrierHz => 38000;

  // Timing: kMideaTick = 80us.
  static const int _hdrMark = 4480; // 56 * 80
  static const int _hdrSpace = 4480; // 56 * 80
  static const int _bitMark = 560; //  7 * 80
  static const int _oneSpace = 1680; // 21 * 80
  static const int _zeroSpace = 560; //  7 * 80
  static const int _minGap = 5600; // (56 + 7 + 7) * 80

  static const AcTiming _t = AcTiming(
    leadMark: _hdrMark,
    leadSpace: _hdrSpace,
    bitMark: _bitMark,
    oneSpace: _oneSpace,
    zeroSpace: _zeroSpace,
    sectionGap: _minGap,
  );

  // Celsius temperature bounds (kMideaACMinTempC = 17, kMideaACMaxTempC = 30).
  static const int _minTempC = 17;
  static const int _maxTempC = 30;

  // Mode enum, per ir_Midea.h:
  //   kMideaACCool=0, kMideaACDry=1, kMideaACAuto=2, kMideaACHeat=3,
  //   kMideaACFan=4.
  static int _modeBits(AcMode m) {
    switch (m) {
      case AcMode.cool:
        return 0;
      case AcMode.dry:
        return 1;
      case AcMode.auto:
        return 2;
      case AcMode.heat:
        return 3;
      case AcMode.fan:
        return 4;
    }
  }

  // Fan enum (Auto=0, Low=1, Med=2, High=3).
  static int _fanBits(AcFan f) {
    switch (f) {
      case AcFan.auto:
        return 0;
      case AcFan.low:
        return 1;
      case AcFan.medium:
        return 2;
      case AcFan.high:
        return 3;
    }
  }

  static int _reverse8(int b) {
    var r = 0;
    for (var i = 0; i < 8; i++) {
      r = (r << 1) | ((b >> i) & 1);
    }
    return r & 0xFF;
  }

  /// Midea checksum: sum of the bit-reversed values of bytes 1..5, negate
  /// (256 - sum) in 8 bits, then bit-reverse the result. Stored in byte 0.
  static int _checksum(List<int> state) {
    var sum = 0;
    for (var i = 1; i < 6; i++) {
      sum += _reverse8(state[i]);
    }
    sum &= 0xFF;
    sum = (256 - sum) & 0xFF;
    return _reverse8(sum);
  }

  @override
  List<int> encode(AcState state) {
    // Midea's floor is 17C; AcState.temp may be as low as 16, so clamp up.
    final temp = state.tempIn(_minTempC, _maxTempC);

    // state[0] = LSB byte ... state[5] = MSB byte (matches the union layout).
    final st = List<int>.filled(6, 0);

    // Byte 5: Type = Command (0b001), Header = 0b10100  -> 0xA1.
    st[5] = 0xA1;

    // Byte 4: Mode (bits 0-2), Fan (bits 3-4), Sleep (bit 6), Power (bit 7).
    // Swing has no field in the Midea 48-bit command frame, so it is ignored
    // (this protocol has no swing/oscillation bit). Sleep left off (0).
    st[4] = (_modeBits(state.mode) & 0x07) |
        ((_fanBits(state.fan) & 0x03) << 3) |
        ((state.power ? 1 : 0) << 7);

    // Byte 3: Temp = (Celsius - 17) in bits 0-4, useFahrenheit = 0 (bit 5).
    st[3] = (temp - _minTempC) & 0x1F;

    // Bytes 2 & 1: unused SensorTemp / OffTimer area, fixed 0xFF per default.
    st[2] = 0xFF;
    st[1] = 0xFF;

    // Byte 0: checksum over bytes 1..5.
    st[0] = _checksum(st);

    // The radio sends the most-significant byte (byte 5) first, MSB-bit-first.
    // acFrameLsb emits array order, LSB-bit-first, so reverse both the byte
    // order and each byte's bit order to reproduce the exact on-air waveform.
    final normal = <int>[
      for (var i = 5; i >= 0; i--) _reverse8(st[i]),
    ];
    // Second half: entirely inverted payload (~data), same wire ordering.
    final inverted = <int>[
      for (final b in normal) (~b) & 0xFF,
    ];

    // Two leader-framed sections separated by kMideaMinGap.
    return acFrameTwoSection(normal, inverted, _t);
  }
}

/// Daikin "DaikinESP" protocol — the base 280-bit / 35-byte Daikin format used
/// across most Daikin split units (IRremoteESP8266 `IRDaikinESP`, ir_Daikin.cpp).
///
/// Wire format (all LSB-first, 38 kHz):
///   - A 5-bit "leader" of zero bits, sent with the data bit timing, with the
///     final bit's space extended by the footer gap (the cpp's "header for the
///     header").
///   - Three pulse-distance sections, each prefixed by a header mark/space:
///       section 1 = bytes  0..7   (byte  7 = additive checksum of 0..6)
///       section 2 = bytes  8..15  (byte 15 = additive checksum of 8..14)
///       section 3 = bytes 16..34  (byte 34 = additive checksum of 16..33)
///     Sections are separated by the footer gap; each ends with a trailing bit
///     mark.
///
/// Timings (µs), from ir_Daikin.h:
///   HdrMark 3650, HdrSpace 1623, BitMark 428, OneSpace 1280, ZeroSpace 428,
///   Gap 29000. Every section's footer SPACE in the cpp is (ZeroSpace + Gap)
///   = 428 + 29000 = 29428 µs — see kDaikinZeroSpace + kDaikinGap in sendDaikin.
///
/// State byte layout (the bytes this encoder actually drives):
///   byte 21: bit0 Power, bit1 OnTimer, bit2 OffTimer, bit3 = 1, bits4-6 Mode.
///   byte 22: Temp encoded as (Celsius * 2).
///   byte 24: low nibble SwingV (0xF on / 0x0 off), high nibble Fan.
/// Fan encoding: normal speeds are stored as (2 + speed) where speed is 1..5;
/// Auto = 0xA, Quiet = 0xB.
class DaikinAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'daikin';

  @override
  String get displayName => 'Daikin';

  @override
  int get carrierHz => 38000;

  // Timings (microseconds) — ir_Daikin.h base DAIKIN constants.
  static const int _hdrMark = 3650;
  static const int _hdrSpace = 1623;
  static const int _bitMark = 428;
  static const int _oneSpace = 1280;
  static const int _zeroSpace = 428;
  static const int _gap = 29000;

  // The footer SPACE emitted after the leader and after each data section.
  // sendDaikin passes kDaikinZeroSpace + kDaikinGap as the footerspace for the
  // leader and all three section sendGeneric() calls.
  static const int _footerGap = _zeroSpace + _gap; // 29428

  // Mode field values (byte 21, bits 4-6).
  static const int _modeAuto = 0x0; // 0b000
  static const int _modeDry = 0x2; // 0b010
  static const int _modeCool = 0x3; // 0b011
  static const int _modeHeat = 0x4; // 0b100
  static const int _modeFan = 0x6; // 0b110

  // Fan field values (byte 24, high nibble).
  static const int _fanAuto = 0xA; // 0b1010
  static const int _fanMinSpeed = 1; // maps to stored 2+1 = 3
  static const int _fanMaxSpeed = 5; // maps to stored 2+5 = 7

  static const int _minTemp = 10;
  static const int _maxTemp = 32;

  static const AcTiming _timing = AcTiming(
    leadMark: _hdrMark,
    leadSpace: _hdrSpace,
    bitMark: _bitMark,
    oneSpace: _oneSpace,
    zeroSpace: _zeroSpace,
  );

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);

    final section1 = bytes.sublist(0, 8);
    final section2 = bytes.sublist(8, 16);
    final section3 = bytes.sublist(16, 35);

    final out = <int>[];

    // Leader: 5 zero bits sent with data-bit timing ("header for the header").
    // Each is bitMark + zeroSpace; the run is terminated by a bit mark and then
    // the footer gap (zeroSpace + gap) before section 1 begins.
    for (var i = 0; i < 5; i++) {
      out.add(_bitMark);
      out.add(_zeroSpace);
    }
    out.add(_bitMark);
    out.add(_footerGap);

    // Three pulse-distance sections, gap-separated. acFrameLsb supplies the
    // HdrMark/HdrSpace section header and the trailing footer (stop) mark; the
    // footer SPACE that follows is (zeroSpace + gap).
    out.addAll(acFrameLsb(section1, _timing));
    out.add(_footerGap);
    out.addAll(acFrameLsb(section2, _timing));
    out.add(_footerGap);
    out.addAll(acFrameLsb(section3, _timing));

    return out;
  }

  /// Builds the 35 protocol bytes: fixed header/signature bytes from
  /// `stateReset()`, then the mutable fields overlaid, then the 3 checksums.
  List<int> _stateBytes(AcState s) {
    final b = List<int>.filled(35, 0);

    // Fixed bytes from IRDaikinESP::stateReset().
    b[0] = 0x11;
    b[1] = 0xDA;
    b[2] = 0x27;
    b[4] = 0xC5;
    b[8] = 0x11;
    b[9] = 0xDA;
    b[10] = 0x27;
    b[12] = 0x42;
    b[16] = 0x11;
    b[17] = 0xDA;
    b[18] = 0x27;
    b[21] = 0x49; // power/mode field default (overwritten below)
    b[22] = 0x1E; // temp default 15.0*2 (overwritten below)
    b[24] = 0xB0; // fan/swingV default (overwritten below)
    b[27] = 0x06;
    b[28] = 0x60;
    b[31] = 0xC0;

    // byte 21: Power (bit0), OnTimer/OffTimer off, bit3 = 1, Mode (bits 4-6).
    var b21 = 0x08; // bit3 always set
    if (s.power) b21 |= 0x01;
    b21 |= (_modeBits(s.mode) & 0x07) << 4;
    b[21] = b21;

    // byte 22: temperature * 2, clamped to the Daikin range.
    final t = s.temp.clamp(_minTemp, _maxTemp);
    b[22] = (t * 2) & 0xFF;

    // byte 24: high nibble Fan, low nibble SwingV (0xF on / 0x0 off).
    final fan = _fanBits(s.fan) & 0x0F;
    final swingV = s.swing ? 0x0F : 0x00;
    b[24] = (fan << 4) | swingV;

    // SwingH (byte 25 low nibble) follows SwingV in the real remote; mirror it
    // so horizontal louvres track the same on/off as vertical (AcState.swing is
    // a single bool — source has independent SwingV/SwingH).
    b[25] = (b[25] & 0xF0) | (s.swing ? 0x0F : 0x00);

    // Checksums: additive sum & 0xFF of each section's data bytes.
    b[7] = acSumChecksum(b.sublist(0, 7));
    b[15] = acSumChecksum(b.sublist(8, 15));
    b[34] = acSumChecksum(b.sublist(16, 34));

    return b;
  }

  /// Maps [AcMode] to the byte-21 mode field.
  int _modeBits(AcMode m) => switch (m) {
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.heat => _modeHeat,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
      };

  /// Maps [AcFan] to the stored byte-24 fan value, matching IRDaikinESP::setFan:
  /// normal speeds 1..5 are stored as (2 + speed); auto is 0xA.
  /// AcFan.low/medium/high pick speeds 1/3/5 within the 1..5 range.
  int _fanBits(AcFan f) {
    if (f == AcFan.auto) return _fanAuto;
    final speed = switch (f) {
      AcFan.auto => _fanMinSpeed, // unreachable (handled above)
      AcFan.low => _fanMinSpeed, // 1
      AcFan.medium => 3,
      AcFan.high => _fanMaxSpeed, // 5
    };
    final clamped = speed.clamp(_fanMinSpeed, _fanMaxSpeed);
    return 2 + clamped; // stored value, per setFan()
  }
}

/// Panasonic AC (Kaseikyo-based) IR encoder, NKE/DKE common variant.
///
/// Ported faithfully from IRremoteESP8266 `src/ir_Panasonic.cpp` and
/// `src/ir_Panasonic.h` (the `kPanasonicAc*` definitions and the
/// `IRPanasonicAc` setters).
///
/// Wire format: 27 state bytes, sent LSB-first in two sections — the first 8
/// bytes, then the remaining 19 — each section preceded by its own header and
/// separated by a 10 ms gap. Carrier is 36.7 kHz (not the usual 38 kHz).
///
/// Timings (µs): header 3456/1728, bit mark 432, one-space 1296, zero-space
/// 432, section gap 10000.
class PanasonicAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'panasonic_ac';

  @override
  String get displayName => 'Panasonic AC';

  @override
  int get carrierHz => 36700; // kPanasonicFreq

  static const AcTiming _t = AcTiming(
    leadMark: 3456, // kPanasonicHdrMark
    leadSpace: 1728, // kPanasonicHdrSpace
    bitMark: 432, // kPanasonicBitMark
    oneSpace: 1296, // kPanasonicOneSpace
    zeroSpace: 432, // kPanasonicZeroSpace
    sectionGap: 10000, // kPanasonicAcSectionGap
  );

  /// kPanasonicKnownGoodState[27] — the fixed NKE/DKE skeleton. Only the
  /// mutable fields (power/mode @13, temp @14, fan/swing @16, checksum @26)
  /// are overwritten; every other byte (frame prefix, byte19=0x0E,
  /// byte20=0xE0, byte23=0x81, ion/filter byte22, etc.) stays at default.
  static const List<int> _knownGoodState = [
    0x02, 0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x06, //
    0x02, 0x20, 0xE0, 0x04, 0x00, 0x00, 0x00, 0x80, //
    0x00, 0x00, 0x00, 0x0E, 0xE0, 0x00, 0x00, 0x81, //
    0x00, 0x00, 0x00,
  ];

  // Mode enum values (kPanasonicAc*).
  static const int _modeAuto = 0;
  static const int _modeDry = 2;
  static const int _modeCool = 3;
  static const int _modeHeat = 4;
  static const int _modeFan = 6;

  // Fan enum values (raw, before the +3 delta when stored).
  static const int _fanLow = 1; // kPanasonicAcFanLow
  static const int _fanMed = 2; // kPanasonicAcFanMed
  static const int _fanHigh = 3; // kPanasonicAcFanHigh
  static const int _fanAuto = 7; // kPanasonicAcFanAuto
  static const int _fanDelta = 3; // kPanasonicAcFanDelta

  // Vertical swing values.
  static const int _swingVMiddle = 0x3; // kPanasonicAcSwingVMiddle
  static const int _swingVAuto = 0xF; // kPanasonicAcSwingVAuto

  static const int _checksumInit = 0xF4; // kPanasonicAcChecksumInit

  @override
  List<int> encode(AcState state) {
    final b = List<int>.of(_knownGoodState);

    final mode = _modeBits(state.mode);

    // Byte 13: high nibble = mode, bit 0 = power.
    // (Source clears the low nibble before writing mode; we rebuild the byte
    // so only the power bit and mode nibble are set, matching known-good.)
    b[13] = (mode & 0x0F) << 4;
    if (state.power) b[13] |= 1; // kPanasonicAcPowerOffset = 0

    // Byte 14: temperature at offset 1, width 5 (raw Celsius, no offset).
    // Fan mode forces 27°C (kPanasonicAcFanModeTemp), as the source does.
    final temp =
        state.mode == AcMode.fan ? 27 : state.tempIn(16, 30); // clamp 16..30
    b[14] = (b[14] & ~(0x1F << 1)) | ((temp & 0x1F) << 1);

    // Byte 16: high nibble = fan speed + delta(3); low nibble = vertical swing.
    final fanStored = (_fanBits(state.fan) + _fanDelta) & 0x0F;
    final swing = state.swing ? _swingVAuto : _swingVMiddle;
    b[16] = (fanStored << 4) | (swing & 0x0F);

    // Byte 26 (last): checksum = (0xF4 + sum of bytes 0..25) & 0xFF.
    b[26] = acSumChecksum(b.sublist(0, 26), init: _checksumInit);

    // Two sections: first 8 bytes, then the remaining 19.
    final section1 = b.sublist(0, 8);
    final section2 = b.sublist(8);
    return acFrameTwoSection(section1, section2, _t);
  }

  int _modeBits(AcMode m) => switch (m) {
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
        AcMode.heat => _modeHeat,
      };

  int _fanBits(AcFan f) => switch (f) {
        AcFan.auto => _fanAuto,
        AcFan.low => _fanLow,
        AcFan.medium => _fanMed,
        AcFan.high => _fanHigh,
      };
}

/// Toshiba AC air-conditioner IR protocol.
///
/// Ported from IRremoteESP8266 `ir_Toshiba.cpp` / `ir_Toshiba.h`
/// (github.com/crankyoldgit/IRremoteESP8266). This implements the standard
/// 9-byte / 72-bit message ("kToshibaACStateLength = 9").
///
/// Timing (µs): header 4400/4300, bit mark 580, "1" space 1600, "0" space 490.
/// The whole frame is transmitted twice with a gap between. sendToshibaAC's
/// default repeat is kToshibaACMinRepeat (== kSingleRepeat == 1), i.e. sent
/// twice, and sendGeneric is called with kToshibaAcUsualGap (7400µs) as the
/// trailing/inter-message space — NOT kToshibaAcMinGap (4600µs).
///
/// Byte layout (LSB-first on the wire; the ToshibaProtocol union):
///   byte 0: 0xF2 (signature)
///   byte 1: 0x0D (== ~0xF2, the inverted signature)
///   byte 2: Length(bits0-3) | Model(bits4-7).  Standard msg Length=3, Model=0
///           => 0x03
///   byte 3: 0xFC (== ~0x03, inverted byte 2)
///   byte 4: 0x01 (LongMsg bit3 / ShortMsg bit5 both 0 here; matches the
///           library reset state {0xF2,0x0D,0x03,0xFC,0x01,...})
///   byte 5: Swing(bits0-2) | Temp(bits4-7), Temp = celsius - 17
///   byte 6: Mode(bits0-2) | Fan(bits5-7)
///   byte 7: Filter(bit4); 0 here
///   byte 8: checksum = XOR of bytes 0..7  (calcChecksum -> xorBytes(state,len-1))
class ToshibaAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'toshiba_ac';

  @override
  String get displayName => 'Toshiba AC';

  @override
  int get carrierHz => 38000;

  // kToshibaAc* timing constants (microseconds).
  static const _timing = AcTiming(
    leadMark: 4400, // kToshibaAcHdrMark
    leadSpace: 4300, // kToshibaAcHdrSpace
    bitMark: 580, // kToshibaAcBitMark
    oneSpace: 1600, // kToshibaAcOneSpace
    zeroSpace: 490, // kToshibaAcZeroSpace
    // sendToshibaAC -> sendGeneric(..., kToshibaAcUsualGap, ...) uses 7400µs as
    // the gap between the two repeats (kToshibaAcMinGap=4600 is unused here).
    sectionGap: 7400, // kToshibaAcUsualGap
  );

  // Mode values (kToshibaAcAuto/Cool/Dry/Heat/Fan/Off).
  static const int _modeAuto = 0;
  static const int _modeCool = 1;
  static const int _modeDry = 2;
  static const int _modeHeat = 3;
  static const int _modeFan = 4;
  static const int _modeOff = 7; // kToshibaAcOff: power-off is encoded as a mode

  // Fan values as stored in the Fan field. setFan() bumps user speeds above
  // Auto by one, so Auto=0, Min=1, Med=3, Max=5 are the actual on-wire values.
  static const int _fanAuto = 0; // kToshibaAcFanAuto
  static const int _fanMin = 1; // kToshibaAcFanMin
  static const int _fanMed = 3; // kToshibaAcFanMed
  static const int _fanMax = 5; // kToshibaAcFanMax

  // Swing values. kToshibaAcSwingOn = 1, kToshibaAcSwingOff = 2.
  static const int _swingOn = 1;
  static const int _swingOff = 2;

  // kToshibaAcMinTemp = 17, kToshibaAcMaxTemp = 30. (Our AcState allows 16; we
  // clamp up to the Toshiba minimum.)
  static const int _minTemp = 17;
  static const int _maxTemp = 30;

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);
    // The frame is sent twice (sendToshibaAC default repeat=kSingleRepeat=1):
    // one section, gap (kToshibaAcUsualGap), then the identical section again.
    return acFrameTwoSection(bytes, bytes, _timing);
  }

  List<int> _stateBytes(AcState s) {
    final b = List<int>.filled(9, 0);

    // Fixed header / framing bytes for a standard 9-byte message.
    b[0] = 0xF2; // signature
    b[1] = 0x0D; // ~0xF2
    b[2] = 0x03; // Length=3, Model=0
    b[3] = 0xFC; // ~0x03
    b[4] = 0x01; // padding/flags (LongMsg=ShortMsg=0)

    // Power is implicit in Mode: off => kToshibaAcOff.
    final mode = s.power ? _modeValue(s.mode) : _modeOff;

    // Temperature: stored as (celsius - kToshibaAcMinTemp) in bits 4-7 of byte5.
    final temp = s.tempIn(_minTemp, _maxTemp) - _minTemp;
    // Swing in bits 0-2 of byte5.
    final swing = s.swing ? _swingOn : _swingOff;
    b[5] = (swing & 0x07) | ((temp & 0x0F) << 4);

    // Mode in bits 0-2, Fan in bits 5-7 of byte6.
    b[6] = (mode & 0x07) | ((_fanValue(s.fan) & 0x07) << 5);

    // byte7: Filter flag (bit4) left 0.

    // Checksum: XOR of bytes 0..7, stored in the last byte.
    b[8] = acXorChecksum(b.sublist(0, 8));
    return b;
  }

  int _modeValue(AcMode m) => switch (m) {
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.dry => _modeDry,
        AcMode.heat => _modeHeat,
        AcMode.fan => _modeFan,
      };

  int _fanValue(AcFan f) => switch (f) {
        AcFan.auto => _fanAuto,
        AcFan.low => _fanMin,
        AcFan.medium => _fanMed,
        AcFan.high => _fanMax,
      };
}

/// Hitachi AC — base 28-byte HITACHI_AC protocol.
///
/// Ported from IRremoteESP8266 `ir_Hitachi.cpp` / `ir_Hitachi.h`
/// (the base `IRHitachiAc` / `kHitachiAcStateLength == 28` variant, NOT
/// AC1/AC264/AC296/AC344/AC424).
///
/// On-wire framing (microseconds): header 3300/1700, bit mark 400, "1" space
/// 1250, "0" space 500. Each byte is transmitted **MSB-first** with no byte
/// inversion, so this encoder does not use the LSB-first [acFrameLsb] helper —
/// it emits bits MSB-first by hand.
///
/// The IRremoteESP8266 union stores the Mode/Temp/Fan bytes already
/// bit-reversed (`setMode` does `_.Mode = reverseBits(newmode, 8)`, etc.); the
/// raw array then holds the actual on-wire bytes. We reproduce those exact
/// bytes via [_rev8].
class HitachiAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'hitachi_ac';

  @override
  String get displayName => 'Hitachi';

  @override
  int get carrierHz => 38000;

  static const AcTiming _t = AcTiming(
    leadMark: 3300,
    leadSpace: 1700,
    bitMark: 400,
    oneSpace: 1250,
    zeroSpace: 500,
  );

  static const int _stateLen = 28;

  static const int _minTemp = 16;
  // Source allows up to 32; our UI tops out at 30 (AcState.maxTemp).
  static const int _maxTemp = 30;

  // Mode values (pre bit-reverse), from ir_Hitachi.h.
  static const int _modeAuto = 0x2;
  static const int _modeHeat = 0x3;
  static const int _modeCool = 0x4;
  static const int _modeDry = 0x5;
  static const int _modeFan = 0xC;

  // Fan speed values (pre bit-reverse).
  static const int _fanAuto = 1;
  static const int _fanLow = 2;
  static const int _fanMed = 3;
  static const int _fanHigh = 5;

  /// Reverses the 8 bits of [v] — equivalent to IRremoteESP8266 reverseBits(v,8).
  static int _rev8(int v) {
    var x = v & 0xFF;
    x = ((x & 0xF0) >> 4) | ((x & 0x0F) << 4);
    x = ((x & 0xCC) >> 2) | ((x & 0x33) << 2);
    x = ((x & 0xAA) >> 1) | ((x & 0x55) << 1);
    return x & 0xFF;
  }

  int _modeValue(AcMode m) => switch (m) {
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.heat => _modeHeat,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
      };

  int _fanValue(AcFan f, AcMode mode) {
    var speed = switch (f) {
      AcFan.auto => _fanAuto,
      AcFan.low => _fanLow,
      AcFan.medium => _fanMed,
      AcFan.high => _fanHigh,
    };
    // Library setFan clamps BOTH ends per mode:
    //   Dry  -> [Low .. Low+1(Med)]  (no Auto, no High)
    //   Fan  -> [Low .. High]        (no Auto)
    //   else -> [Auto .. High]
    var fanMin = _fanAuto;
    var fanMax = _fanHigh;
    if (mode == AcMode.dry) {
      fanMin = _fanLow;
      fanMax = _fanLow + 1; // = Med
    } else if (mode == AcMode.fan) {
      fanMin = _fanLow;
    }
    if (speed < fanMin) speed = fanMin;
    if (speed > fanMax) speed = fanMax;
    return speed;
  }

  /// Builds the 28 on-wire bytes for [state], reproducing the IRremoteESP8266
  /// default header/pad bytes and field encodings, then the checksum.
  List<int> _stateBytes(AcState state) {
    // stateReset() defaults.
    final b = List<int>.filled(_stateLen, 0x00);
    b[0] = 0x80;
    b[1] = 0x08;
    b[2] = 0x0C;
    b[3] = 0x02;
    b[4] = 0xFD;
    b[5] = 0x80;
    b[6] = 0x7F;
    b[7] = 0x88;
    b[8] = 0x48;
    b[9] = 0x10; // overwritten below by temp logic
    b[14] = 0x60; // SwingV base (SwingV is bit7)
    b[15] = 0x60; // SwingH base (SwingH is bit7)
    b[24] = 0x80;

    // Mode (byte 10) — stored bit-reversed.
    b[10] = _rev8(_modeValue(state.mode));

    // Temperature (byte 11) and byte 9 marker.
    if (state.mode == AcMode.fan) {
      // Fan mode: setMode(kHitachiAcFan) -> setTemp(64). setTemp ALWAYS does
      // reverseBits(temp << 1, 8), so 64 -> reverseBits(128,8) = 0x01.
      // temp(64) != minTemp(16) -> raw[9] = 0x10. AcState.temp is ignored,
      // matching the library.
      b[11] = _rev8((64 << 1) & 0xFF);
      b[9] = 0x10;
    } else {
      final temp = state.temp.clamp(_minTemp, _maxTemp);
      b[11] = _rev8((temp << 1) & 0xFF);
      b[9] = (temp == _minTemp) ? 0x90 : 0x10;
    }

    // Fan (byte 13) — stored bit-reversed.
    b[13] = _rev8(_fanValue(state.fan, state.mode));

    // SwingV is bit7 (0x80) of byte 14 (struct: `:7` padding then `SwingV:1`).
    // SwingH (byte 15, also bit7) is left off. Our single user swing flag maps
    // to vertical swing, the common user-facing control.
    if (state.swing) {
      b[14] |= 0x80;
    } else {
      b[14] &= ~0x80;
    }

    // Power is bit0 (0x01) of byte 17 (struct: `Power:1` then `:7` padding).
    b[17] = state.power ? 0x01 : 0x00;

    // Checksum (byte 27): sum=62; subtract reverseBits(state[i]) for the first
    // 27 bytes; store reverseBits(sum & 0xFF, 8).
    var sum = 62;
    for (var i = 0; i < _stateLen - 1; i++) {
      sum -= _rev8(b[i]);
    }
    b[_stateLen - 1] = _rev8(sum & 0xFF);

    return b;
  }

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);
    // MSB-first pulse-distance frame (the base Hitachi AC is MSB-first; the
    // shared acFrameLsb helper is LSB-first, so we emit bits by hand).
    final out = <int>[_t.leadMark, _t.leadSpace];
    for (final byte in bytes) {
      for (var i = 7; i >= 0; i--) {
        out.add(_t.bitMark);
        out.add(((byte >> i) & 1) == 1 ? _t.oneSpace : _t.zeroSpace);
      }
    }
    out.add(_t.bitMark); // trailing stop mark
    return out;
  }
}

/// LG air-conditioner IR encoder (LG 28-bit protocol).
///
/// Ported faithfully from IRremoteESP8266 `ir_LG.cpp` / `ir_LG.h`
/// (github.com/crankyoldgit/IRremoteESP8266). This is the classic "LG"
/// (28-bit) A/C codeset (e.g. remote LG6711A20083V), NOT the 32-bit "LG2"
/// Samsung-like variant.
///
/// Wire format (sendGeneric in sendLG, MSBfirst == true):
///   header mark 8500us, header space 4250us,
///   28 data bits MSB-first (bitMark 550us + 1600us for '1' / 550us for '0'),
///   trailing bitMark stop. Carrier 38 kHz.
///
/// 28-bit value layout (LGProtocol union, LSB..MSB):
///   bits [3:0]   Sum   (4-bit checksum)
///   bits [7:4]   Fan   (4 bits)
///   bits [11:8]  Temp  (4 bits, value = celsius - 15)
///   bits [14:12] Mode  (3 bits)
///   bits [17:15] (reserved, 3 bits, 0)
///   bits [19:18] Power (2 bits)
///   bits [27:20] Sign  (8 bits, 0x88 signature)
///
/// Checksum: irutils::sumNibbles(state >> 4, 4) -> sum the four nibbles in
/// bits [19:4] (Fan, Temp, Mode+reserved, Power), keep low 4 bits.
class LgAcAcEncoder implements AcIrEncoder {
  const LgAcAcEncoder();

  @override
  String get brandId => 'lg_ac';

  @override
  String get displayName => 'LG (A/C)';

  @override
  int get carrierHz => 38000;

  // --- Source constants (ir_LG.h / ir_LG.cpp) ---
  static const int _kSignature = 0x88; // kLgAcSignature
  static const int _kTempAdjust = 15; // kLgAcTempAdjust
  static const int _kMinTemp = 16; // kLgAcMinTemp
  static const int _kMaxTemp = 30; // kLgAcMaxTemp

  // Mode values (kLgAcCool/Dry/Fan/Auto/Heat).
  static const int _kCool = 0; // 0b000
  static const int _kDry = 1; // 0b001
  static const int _kFan = 2; // 0b010
  static const int _kAuto = 3; // 0b011
  static const int _kHeat = 4; // 0b100

  // Fan values (kLgAcFan*). Lowest=0, Low=1, Medium=2, Max=4, Auto=5, High=10.
  static const int _kFanLow = 1; // 0b0001
  static const int _kFanMedium = 2; // 0b0010
  static const int _kFanHigh = 10; // 0b1010
  static const int _kFanAuto = 5; // 0b0101

  // Power values (2-bit field). On=0b00, Off=0b11.
  static const int _kPowerOn = 0;
  static const int _kPowerOff = 3;

  static const AcTiming _timing = AcTiming(
    leadMark: 8500, // kLgHdrMark
    leadSpace: 4250, // kLgHdrSpace
    bitMark: 550, // kLgBitMark
    oneSpace: 1600, // kLgOneSpace
    zeroSpace: 550, // kLgZeroSpace
  );

  int _modeBits(AcMode m) {
    switch (m) {
      case AcMode.cool:
        return _kCool;
      case AcMode.heat:
        return _kHeat;
      case AcMode.dry:
        return _kDry;
      case AcMode.fan:
        return _kFan;
      case AcMode.auto:
        return _kAuto;
    }
  }

  int _fanBits(AcFan f) {
    switch (f) {
      case AcFan.auto:
        return _kFanAuto;
      case AcFan.low:
        return _kFanLow;
      case AcFan.medium:
        return _kFanMedium;
      case AcFan.high:
        return _kFanHigh;
    }
  }

  @override
  List<int> encode(AcState state) {
    // Temperature: clamp to 16..30, stored as (celsius - 15) in 4 bits.
    final temp = state.tempIn(_kMinTemp, _kMaxTemp);
    final tempField = (temp - _kTempAdjust) & 0xF;

    final fanField = _fanBits(state.fan) & 0xF;
    final modeField = _modeBits(state.mode) & 0x7;
    final powerField = (state.power ? _kPowerOn : _kPowerOff) & 0x3;

    // NOTE: swing (vertical vane) in the 28-bit codeset is sent as a SEPARATE
    // standalone command (kLgAcSwingV*), not a bit in the state word, so there
    // is no clean per-frame mapping. We leave the reserved bits at 0 and ignore
    // state.swing here (faithful to the state frame). A dedicated swing frame
    // would be a different transmission.
    final reservedField = 0;

    // Assemble the 28-bit value (Sum nibble left as 0 for now).
    var raw = 0;
    raw |= (fanField & 0xF) << 4;
    raw |= (tempField & 0xF) << 8;
    raw |= (modeField & 0x7) << 12;
    raw |= (reservedField & 0x7) << 15;
    raw |= (powerField & 0x3) << 18;
    raw |= (_kSignature & 0xFF) << 20;

    // Checksum: sum the four nibbles above the checksum nibble (bits 19..4),
    // keep low 4 bits. calcChecksum = sumNibbles(state >> 4, 4).
    final body = raw >> 4;
    var sum = 0;
    for (var i = 0; i < 4; i++) {
      sum += (body >> (i * 4)) & 0xF;
    }
    raw |= sum & 0xF;

    // Emit 28 bits MSB-first (LG sendGeneric uses MSBfirst == true).
    final out = <int>[_timing.leadMark, _timing.leadSpace];
    for (var i = 27; i >= 0; i--) {
      out.add(_timing.bitMark);
      final bit = (raw >> i) & 1;
      out.add(bit == 1 ? _timing.oneSpace : _timing.zeroSpace);
    }
    out.add(_timing.bitMark); // trailing stop mark
    return out;
  }
}

/// Samsung A/C protocol, ported from IRremoteESP8266 `ir_Samsung.cpp`
/// (`kSamsungAc*`). A 14-byte message sent as TWO 7-byte sections.
///
/// IMPORTANT framing detail (this is what `sendSamsungAC` actually emits):
///   * ONE outer header at the very start: HdrMark 690 / HdrSpace 17844.
///   * Then, for EACH 7-byte section:
///       SectionMark 3086, SectionSpace 8864, 56 data bits (LSB-first),
///       BitMark 586 (footer mark), SectionGap 2886 (footer space).
/// The per-section header is the SECTION mark/space (3086/8864), NOT the outer
/// header (690/17844). The shared `acFrameTwoSection` helper assumes the same
/// leader on every section and has no notion of a separate outer header, so it
/// cannot represent this protocol — the burst is built explicitly below.
///
/// Timing (µs), from the source:
///   kSamsungAcHdrMark      690
///   kSamsungAcHdrSpace     17844
///   kSamsungAcSectionMark  3086
///   kSamsungAcSectionSpace 8864
///   kSamsungAcBitMark      586
///   kSamsungAcOneSpace     1432
///   kSamsungAcZeroSpace    436
///   kSamsungAcSectionGap   2886
///
/// Byte/bit layout (LSB-first within each byte; from the `SamsungProtocol`
/// standard struct, padding fields omitted):
///   byte 1  bits4-7  Sum1Lower   (section-1 checksum, low nibble)
///   byte 2  bits0-3  Sum1Upper   (section-1 checksum, high nibble)
///   byte 5  bit5     Quiet
///   byte 6  bits4-5  Power1      (0b11 = on, 0b00 = off)
///   byte 8  bits4-7  Sum2Lower   (section-2 checksum, low nibble)
///   byte 9  bits0-3  Sum2Upper   (section-2 checksum, high nibble)
///   byte 9  bits4-6  Swing       (0b010 vertical, 0b111 off)
///   byte 11 bits4-7  Temp        (Celsius - kSamsungAcMinTemp(16))
///   byte 12 bits1-3  Fan
///   byte 12 bits4-6  Mode
///   byte 13 bits4-5  Power2      (0b11 = on, 0b00 = off)
///
/// Checksum (per 7-byte section, `calcSectionChecksum`): population count of
/// byte0 (all 8 bits) + byte1's low nibble + byte2's high nibble +
/// bytes 3,4,5,6 (all bits), then XOR 0xFF. The low nibble goes to byte1
/// bits4-7, the high nibble to byte2 bits0-3 (relative to the section start).
/// Section 1 = bytes 0..6, section 2 = bytes 7..13.
class SamsungAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'samsung_ac';

  @override
  String get displayName => 'Samsung AC';

  @override
  int get carrierHz => 38000;

  // Timing constants (µs), kSamsungAc*.
  static const int _hdrMark = 690;
  static const int _hdrSpace = 17844;
  static const int _sectionMark = 3086;
  static const int _sectionSpace = 8864;
  static const int _bitMark = 586;
  static const int _oneSpace = 1432;
  static const int _zeroSpace = 436;
  static const int _sectionGap = 2886;

  // kSamsungAcMinTemp / kSamsungAcMaxTemp.
  static const int _minTemp = 16;
  static const int _maxTemp = 30;

  // Mode enum values (kSamsungAc*).
  static const int _modeAuto = 0;
  static const int _modeCool = 1;
  static const int _modeDry = 2;
  static const int _modeFan = 3;
  static const int _modeHeat = 4;

  // Fan enum values (kSamsungAcFan*). Note: 1, 3, 6, 7 are not used here.
  static const int _fanAuto = 0;
  static const int _fanLow = 2;
  static const int _fanMed = 4;
  static const int _fanHigh = 5;

  // Swing field values.
  static const int _swingVertical = 0x2; // kSamsungAcSwingV (0b010)
  static const int _swingOff = 0x7; // kSamsungAcSwingOff (0b111)

  /// IRremoteESP8266's known-good 14-byte reset state (`kReset`). We seed from
  /// it so all fixed/reserved bits and feature defaults match a real unit, then
  /// overwrite only the controlled fields and recompute both section checksums.
  static const List<int> _template = [
    0x02, 0x92, 0x0F, 0x00, 0x00, 0x00, 0xF0, //
    0x01, 0x02, 0xAE, 0x71, 0x00, 0x15, 0xF0,
  ];

  @override
  List<int> encode(AcState state) {
    final b = List<int>.of(_template);

    // --- Power: Power1 (byte6 bits4-5) and Power2 (byte13 bits4-5). ---
    final pw = state.power ? 0x3 : 0x0;
    b[6] = (b[6] & ~(0x3 << 4)) | (pw << 4);
    b[13] = (b[13] & ~(0x3 << 4)) | (pw << 4);

    // --- Temperature: byte11 bits4-7 = (Celsius - 16). ---
    final temp = state.tempIn(_minTemp, _maxTemp) - _minTemp;
    b[11] = (b[11] & ~(0xF << 4)) | ((temp & 0xF) << 4);

    // --- Mode: byte12 bits4-6. ---
    b[12] = (b[12] & ~(0x7 << 4)) | ((_modeBits(state.mode) & 0x7) << 4);

    // --- Fan: byte12 bits1-3. ---
    b[12] = (b[12] & ~(0x7 << 1)) | ((_fanBits(state.fan) & 0x7) << 1);

    // --- Swing: byte9 bits4-6 (vertical when on, off otherwise). ---
    final swing = state.swing ? _swingVertical : _swingOff;
    b[9] = (b[9] & ~(0x7 << 4)) | ((swing & 0x7) << 4);

    // --- Quiet: byte5 bit5 — left off (template default). ---

    // --- Section checksums (recomputed after the field writes above). ---
    _storeSectionChecksum(b, 0); // section 1: bytes 0..6 -> bytes 1,2
    _storeSectionChecksum(b, 7); // section 2: bytes 7..13 -> bytes 8,9

    return _buildBurst(b);
  }

  /// Builds the raw mark/space burst:
  ///   HdrMark, HdrSpace, then for each section:
  ///   SectionMark, SectionSpace, 56 LSB-first bits, footer BitMark, SectionGap.
  /// Starts with a mark, as required by the AcIrEncoder contract.
  List<int> _buildBurst(List<int> b) {
    final out = <int>[_hdrMark, _hdrSpace];
    for (var sec = 0; sec < 2; sec++) {
      final off = sec * 7;
      out.add(_sectionMark);
      out.add(_sectionSpace);
      for (var i = 0; i < 7; i++) {
        final byte = b[off + i];
        for (var bit = 0; bit < 8; bit++) {
          out.add(_bitMark);
          out.add(((byte >> bit) & 1) == 1 ? _oneSpace : _zeroSpace);
        }
      }
      out.add(_bitMark); // section footer mark
      out.add(_sectionGap); // section footer space / inter-section gap
    }
    return out;
  }

  /// Computes a section's checksum and writes its nibbles back into the section.
  /// [off] is the section's start index (0 or 7).
  void _storeSectionChecksum(List<int> b, int off) {
    final sum = _calcSectionChecksum(b, off);
    // SumLower -> byte (off+1) bits4-7; SumUpper -> byte (off+2) bits0-3.
    b[off + 1] = (b[off + 1] & 0x0F) | ((sum & 0x0F) << 4);
    b[off + 2] = (b[off + 2] & 0xF0) | ((sum >> 4) & 0x0F);
  }

  /// Population-count checksum over a 7-byte section, per `calcSectionChecksum`:
  /// set bits of byte0(full) + byte1 low nibble + byte2 high nibble +
  /// bytes 3,4,5,6(full), then XOR 0xFF. `countBits(section+3, 4)` is the
  /// pointer overload, so it counts over 4 BYTES (3,4,5,6), not 4 bits.
  int _calcSectionChecksum(List<int> b, int off) {
    var sum = 0;
    sum += _popcount(b[off + 0]);
    sum += _popcount(b[off + 1] & 0x0F); // low nibble
    sum += _popcount((b[off + 2] >> 4) & 0x0F); // high nibble
    sum += _popcount(b[off + 3]);
    sum += _popcount(b[off + 4]);
    sum += _popcount(b[off + 5]);
    sum += _popcount(b[off + 6]);
    return (sum ^ 0xFF) & 0xFF;
  }

  int _popcount(int v) {
    var c = 0;
    var x = v & 0xFF;
    while (x != 0) {
      c += x & 1;
      x >>= 1;
    }
    return c;
  }

  int _modeBits(AcMode m) => switch (m) {
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
        AcMode.heat => _modeHeat,
      };

  int _fanBits(AcFan f) => switch (f) {
        AcFan.auto => _fanAuto,
        AcFan.low => _fanLow,
        AcFan.medium => _fanMed,
        AcFan.high => _fanHigh,
      };
}

/// Haier AC — HAIER_AC base 9-byte variant (protocol byte prefix 0xA5).
///
/// Ported faithfully from IRremoteESP8266 `ir_Haier.cpp` / `ir_Haier.h`
/// (the `IRHaierAC` class, NOT the 176-bit / YRW02 / 160 variants).
///
/// Wire format (38 kHz, MSB-first per byte):
///   pre-header mark 3000 + space 3000  (the extra mark/space sendHaierAC emits)
///   header     mark 3000 (kHaierAcHdr) + space 4300 (kHaierAcHdrGap)
///   per bit    mark 520 (kHaierAcBitMark) + space 1650 ("1") / 650 ("0")
///   stop       mark 520
///
/// Because Haier transmits MSB-first, the LSB-first [acFrameLsb] helper does not
/// apply here; the bit loop below emits each byte high-bit first.
class HaierAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'haier_ac';

  @override
  String get displayName => 'Haier AC';

  @override
  int get carrierHz => 38000;

  // --- Timings (microseconds), from ir_Haier.cpp ---
  static const int _preMark = 3000; // sendHaierAC: mark(kHaierAcHdr)
  static const int _preSpace = 3000; // sendHaierAC: space(kHaierAcHdr)
  static const int _hdrMark = 3000; // kHaierAcHdr
  static const int _hdrSpace = 4300; // kHaierAcHdrGap
  static const int _bitMark = 520; // kHaierAcBitMark
  static const int _oneSpace = 1650; // kHaierAcOneSpace
  static const int _zeroSpace = 650; // kHaierAcZeroSpace

  // --- Protocol constants, from ir_Haier.h ---
  static const int _prefix = 0xA5; // kHaierAcPrefix
  static const int _minTemp = 16; // kHaierAcMinTemp
  static const int _maxTemp = 30; // kHaierAcMaxTemp

  // Modes: auto=0, cool=1, dry=2, heat=3, fan=4.
  static const int _modeAuto = 0;
  static const int _modeCool = 1;
  static const int _modeDry = 2;
  static const int _modeHeat = 3;
  static const int _modeFan = 4;

  // Commands (low nibble of byte 1).
  static const int _cmdOff = 0x0; // kHaierAcCmdOff
  static const int _cmdOn = 0x1; // kHaierAcCmdOn

  // SwingV (top 2 bits of byte 2).
  static const int _swingVOff = 0x0; // kHaierAcSwingVOff
  static const int _swingVChg = 0x3; // kHaierAcSwingVChg (continuous sweep)

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);

    final out = <int>[
      _preMark,
      _preSpace,
      _hdrMark,
      _hdrSpace,
    ];
    // MSB-first per byte.
    for (final b in bytes) {
      for (var i = 7; i >= 0; i--) {
        out.add(_bitMark);
        out.add(((b >> i) & 1) == 1 ? _oneSpace : _zeroSpace);
      }
    }
    out.add(_bitMark); // stop mark
    return out;
  }

  /// Builds the 9 state bytes per the `HaierProtocol` bit-field layout.
  List<int> _stateBytes(AcState s) {
    final b = List<int>.filled(9, 0);

    // byte 0: prefix.
    b[0] = _prefix;

    // byte 1: Command (low nibble) | Temp (high nibble). Temp = degC - 16.
    final temp = (s.tempIn(_minTemp, _maxTemp) - _minTemp) & 0x0F;
    final command = s.power ? _cmdOn : _cmdOff;
    b[1] = (command & 0x0F) | (temp << 4);

    // byte 2: CurrHours(0-4) | unknown(bit5, =1 per stateReset) | SwingV(6-7).
    // AcState only has a bool swing → SwingVChg (continuous sweep) when on,
    // SwingVOff when off. (Haier's Up/Down positions have no model field.)
    final swingV = s.swing ? _swingVChg : _swingVOff;
    b[2] = (1 << 5) | ((swingV & 0x03) << 6);

    // byte 3: timer minutes / flags — left 0.

    // byte 4: OffHours(0-4) | Health(bit5). stateReset seeds OffHours=12 for a
    // known-good frame; it does not change AC behavior.
    b[4] = 12 & 0x1F;

    // byte 5: OffMins(0-5) | Fan(6-7). Fan field is INVERTED in this protocol.
    b[5] = (_fanField(s.fan) & 0x03) << 6;

    // byte 6: OnHours(0-4) | Mode(5-7).
    b[6] = (_modeField(s.mode) & 0x07) << 5;

    // byte 7: OnMins(0-5) | Sleep(bit6, kHaierAcSleepBit=0x40). Sleep off → 0.
    b[7] = 0;

    // byte 8: additive checksum over bytes 0..7.
    b[8] = acSumChecksum(b.sublist(0, 8));
    return b;
  }

  /// Mode enum → protocol value.
  int _modeField(AcMode m) => switch (m) {
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.dry => _modeDry,
        AcMode.heat => _modeHeat,
        AcMode.fan => _modeFan,
      };

  /// Fan enum → protocol value. Haier's setFan() inverts the speed when storing:
  /// Low→3, Med→2, High→1, Auto→0. (The raw kHaierAcFanLow/Med/High header
  /// constants are 1/2/3, but setFan() remaps them; this matches the stored
  /// on-wire value.)
  int _fanField(AcFan f) => switch (f) {
        AcFan.auto => 0,
        AcFan.low => 3,
        AcFan.medium => 2,
        AcFan.high => 1,
      };
}

/// Kelon 48-bit IR protocol (also used by rebadged Hisense ACs).
///
/// Ported faithfully from IRremoteESP8266 `ir_Kelon.cpp` / `ir_Kelon.h`
/// (the `KELON` protocol — distinct from the larger `KELON168`).
///
/// Frame: 6 bytes (48 bits), sent LSB-first behind a 9000/4600 leader with a
/// trailing stop mark, 38 kHz. There is NO checksum on the 48-bit variant
/// (only Kelon168 carries one), so none is appended.
///
/// OPEN-LOOP LIMITATION: Kelon encodes power and vertical swing as *toggles*
/// (`PowerToggle` / `SwingVToggle`), not absolute states — the remote has no way
/// to express "be on" vs "be off", only "flip it". Because we cannot read the
/// unit's real state, we set the power-toggle bit on every frame so a press
/// performs the user's intended action; a caller that re-sends an identical
/// [AcState] repeatedly would flip the unit each time. Swing follows the same
/// toggle behaviour and is only pulsed when [AcState.swing] is true.
class KelonAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'kelon';

  @override
  String get displayName => 'Kelon / Hisense';

  @override
  int get carrierHz => 38000; // kKelonFreq

  // Raw timings (µs) from IRsend / ir_Kelon: kKelonHdrMark/Space, kKelonBitMark,
  // kKelonOneSpace, kKelonZeroSpace.
  static const AcTiming _timing = AcTiming(
    leadMark: 9000,
    leadSpace: 4600,
    bitMark: 560,
    oneSpace: 1680,
    zeroSpace: 600,
  );

  // Native Kelon temperature range (kKelonMinTemp..kKelonMaxTemp).
  static const int _minTemp = 18;
  static const int _maxTemp = 32;

  // Mode constants (kKelonModeXxx).
  static const int _modeHeat = 0;
  static const int _modeSmart = 1; // "auto"
  static const int _modeCool = 2;
  static const int _modeDry = 3;
  static const int _modeFan = 4;

  // Public fan constants (kKelonFanXxx) — the protocol stores an inverted form.
  static const int _fanAuto = 0;
  static const int _fanMin = 1;
  static const int _fanMedium = 2;
  static const int _fanMax = 3;

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);
    return acFrameLsb(bytes, _timing);
  }

  /// Builds the 6 protocol bytes from [s], mirroring the KelonProtocol union.
  List<int> _stateBytes(AcState s) {
    final b = List<int>.filled(6, 0);

    // Fixed preamble (stateReset): 0x83, 0x06.
    b[0] = 0x83;
    b[1] = 0x06;

    // byte2: Fan(0-1) | PowerToggle(2) | SleepEnabled(3) | DehumidifierGrade(4-6)
    //        | SwingVToggle(7).
    b[2] = _fanBits(s.fan) & 0x03;
    // Power is a toggle: pulse it so a press applies the user's intent.
    b[2] |= 1 << 2; // PowerToggle
    // SwingVToggle: pulse only when swing requested (toggle field, open-loop).
    if (s.swing) b[2] |= 1 << 7;
    // SleepEnabled (bit3) and DehumidifierGrade (bits4-6) left at 0.

    // byte3: Mode(0-2) | TimerEnabled(3) | Temperature(4-7).
    b[3] = _modeBits(s.mode) & 0x07;
    final t = s.temp.clamp(_minTemp, _maxTemp);
    b[3] |= ((t - _minTemp) & 0x0F) << 4; // _.Temperature = temp - kKelonMinTemp

    // byte4: TimerHalfHour | TimerHours | SmartModeEnabled — all 0.
    // byte5: pad / SuperCool flags — all 0.
    return b;
  }

  int _modeBits(AcMode m) => switch (m) {
        AcMode.auto => _modeSmart,
        AcMode.cool => _modeCool,
        AcMode.heat => _modeHeat,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
      };

  /// Fan is stored inverted in the protocol: `_.Fan = ((fan - 4) * -1) % 4`
  /// over the public fan value (auto=0, min=1, medium=2, max=3).
  int _fanBits(AcFan f) {
    final public = switch (f) {
      AcFan.auto => _fanAuto,
      AcFan.low => _fanMin,
      AcFan.medium => _fanMedium,
      AcFan.high => _fanMax,
    };
    return (((public - 4) * -1) % 4) & 0x03;
  }
}


/// TCL 112-bit A/C protocol (the "Tcl112Ac" decoder in IRremoteESP8266,
/// src/ir_Tcl.cpp / ir_Tcl.h). Used by TCL air conditioners (and several
/// rebadged units).
///
/// Frame: 14 bytes (kTcl112AcStateLength), sent LSB-first, 38 kHz carrier.
/// Timing (µs), verbatim from the source:
///   HdrMark  = 3000, HdrSpace = 1650
///   BitMark  = 500
///   OneSpace = 1050, ZeroSpace = 325
/// (kTcl112AcGap is kDefaultMessageGap — only matters between repeats, so it is
/// not part of a single burst; we emit one frame ending in the stop mark.)
///
/// Byte / bit layout (from the Tcl112Protocol bit-field union in ir_Tcl.h):
///   byte 3  bits0-1 : MsgType            (normal frame = 0x01)
///   byte 5  bit2    : Power              (absolute on/off)
///   byte 6  bits0-3 : Mode
///   byte 7  bits0-3 : Temp               (= 31 - whole°C; see below)
///   byte 8  bits0-2 : Fan
///   byte 8  bits3-5 : SwingV
///   byte 12 bit5    : HalfDegree         (0.5°C fractional flag)
///   byte 12 bit7    : isTcl              (TCL identifier, always 1)
///   byte 13 bits0-7 : Sum                (checksum)
///
/// Mode values   (kTcl112Ac*): Heat=1, Dry=2, Cool=3, Fan=7, Auto=8.
/// Fan values    (kTcl112AcFan*): Auto=0, Min=1, Low=2, Med=3, High=5.
/// Temperature   (setTemp): nrHalfDegrees = round(°C * 2);
///                          HalfDegree = nrHalfDegrees & 1;
///                          Temp = kTcl112AcTempMax(31) - nrHalfDegrees ~/ 2.
///   Range kTcl112AcTempMin=16 .. kTcl112AcTempMax=31. Our AcState.temp is an
///   integer Celsius, so HalfDegree is always 0 and Temp = 31 - °C.
/// Checksum      (calcChecksum -> sumBytes): the 8-bit sum of bytes 0..12 is
///   stored in byte 13. (The library adds a 0xF init offset only for the
///   "special" message where byte3 == 0x02; our normal frame has byte3 == 0x01,
///   so no offset is applied.)
///
/// The non-state header/identity bytes (0,1,2,3 and the isTcl marker) are taken
/// from the library's known-good reset frame
///   {0x23,0xCB,0x26,0x01,0x00,0x24,0x03,0x07,0x40,0x00,0x00,0x00,0x00,0x03}
/// (On, Cool, 24°C) and then the controllable fields are overwritten from the
/// requested [AcState] before the checksum is recomputed.
class Tcl112AcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'tcl112_ac';

  @override
  String get displayName => 'TCL (112-bit)';

  @override
  int get carrierHz => 38000;

  static const AcTiming _t = AcTiming(
    leadMark: 3000,
    leadSpace: 1650,
    bitMark: 500,
    oneSpace: 1050,
    zeroSpace: 325,
  );

  // Mode field values (byte 6, bits 0-3).
  static const int _modeHeat = 1;
  static const int _modeDry = 2;
  static const int _modeCool = 3;
  static const int _modeFan = 7;
  static const int _modeAuto = 8;

  // Fan field values (byte 8, bits 0-2). Note the gap: High == 5, not 4.
  static const int _fanAuto = 0;
  static const int _fanLow = 2; // kTcl112AcFanLow
  static const int _fanMed = 3; // kTcl112AcFanMed
  static const int _fanHigh = 5; // kTcl112AcFanHigh

  // SwingV "on"/"off" (byte 8, bits 3-5). The source exposes discrete vane
  // positions; AcState.swing is a simple toggle, so map true -> "On" (7),
  // false -> "Off" (0). (kTcl112AcSwingVOn = 0b111, kTcl112AcSwingVOff = 0.)
  static const int _swingVOn = 0x7;
  static const int _swingVOff = 0x0;

  static const int _tempMax = 31; // kTcl112AcTempMax
  static const int _tempMin = 16; // kTcl112AcTempMin

  /// Library's known-good frame (On, Cool, 24°C) — supplies the identity/header
  /// bytes we don't model. Controllable fields are overwritten below.
  static const List<int> _base = <int>[
    0x23, 0xCB, 0x26, 0x01, 0x00, 0x24, 0x03, 0x07,
    0x40, 0x00, 0x00, 0x00, 0x00, 0x03,
  ];

  int _modeBits(AcMode m) => switch (m) {
        AcMode.cool => _modeCool,
        AcMode.heat => _modeHeat,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
        AcMode.auto => _modeAuto,
      };

  int _fanBits(AcFan f) => switch (f) {
        AcFan.auto => _fanAuto,
        AcFan.low => _fanLow,
        AcFan.medium => _fanMed,
        AcFan.high => _fanHigh,
      };

  /// Builds the 14 protocol bytes for [s].
  List<int> _stateBytes(AcState s) {
    final b = List<int>.of(_base);

    // byte 5 bit2: Power (clear bit then set per request).
    b[5] = (b[5] & ~(1 << 2)) | (s.power ? (1 << 2) : 0);

    // byte 6 bits0-3: Mode (preserve high nibble: Health/Turbo etc.).
    // In Fan mode the source forces fan High; mirror that below.
    b[6] = (b[6] & 0xF0) | (_modeBits(s.mode) & 0x0F);

    // byte 7 bits0-3: Temp = 31 - whole°C (integer Celsius -> HalfDegree 0).
    final c = s.tempIn(_tempMin, _tempMax);
    b[7] = (b[7] & 0xF0) | ((_tempMax - c) & 0x0F);
    // byte 12 bit5: HalfDegree — always 0 for integer Celsius input.
    b[12] = b[12] & ~(1 << 5);

    // byte 8 bits0-2: Fan, bits3-5: SwingV. Fan mode -> High (per setMode).
    final fan = s.mode == AcMode.fan ? _fanHigh : _fanBits(s.fan);
    final swingV = s.swing ? _swingVOn : _swingVOff;
    b[8] = (b[8] & ~0x3F) | (fan & 0x07) | ((swingV & 0x07) << 3);

    // byte 13: checksum = 8-bit sum of bytes 0..12 (sumBytes, no init offset
    // because byte3 == 0x01, not the 0x02 special message).
    b[13] = acSumChecksum(b.sublist(0, 13));
    return b;
  }

  @override
  List<int> encode(AcState state) => acFrameLsb(_stateBytes(state), _t);
}

// (ac_ir_encoder.dart re-imports appliance.dart, giving us AcState/AcMode/AcFan;
//  ac_protocols.dart provides AcTiming/acFrameLsb/acSumChecksum/tempIn.)

/// Electra AC protocol — ported from IRremoteESP8266 `ir_Electra.cpp` / `.h`.
/// Used by Electra and rebadged Electrolux / Frigidaire units.
///
/// Wire format (verified against the upstream source):
///  * 13 bytes / 104 bits, transmitted LSB-first per byte.
///  * Leader 9166µs mark / 4470µs space; bit mark 646µs; "1" space 1647µs,
///    "0" space 547µs; trailing stop mark. 38kHz carrier.
///  * sendGeneric is called with MSBfirst = false, so the [acFrameLsb] helper
///    (LSB-first) matches the real transmission exactly.
///
/// Byte layout (LSB-first bit-fields, little-endian packing in the source):
///  * byte 0  : constant 0xC3 (stateReset: `_.raw[0] = 0xC3`).
///  * byte 1  : bits 0-2 SwingV, bits 3-7 Temp (value = celsius - 8).
///  * byte 2  : bits 5-7 SwingH.
///  * byte 4  : bits 5-7 Fan.
///  * byte 6  : bits 5-7 Mode.
///  * byte 9  : bit 5 Power.
///  * byte 11 : LightToggle (default 0x08 = kElectraAcLightToggleOff — the
///              value a real Electra frame carries when the light is NOT being
///              toggled; included in the checksum).
///  * byte 12 : checksum = sum of bytes 0..11, masked to 8 bits.
///
/// Mode codes:  auto 0b000, cool 0b001, dry 0b010, heat 0b100, fan 0b110.
/// Fan codes:   auto 0b101, low 0b011, med 0b010, high 0b001.
/// Swing codes: ON 0b000, OFF 0b111 (inverted relative to a normal flag).
class ElectraAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'electra_ac';

  @override
  String get displayName => 'Electra (Electrolux / Frigidaire)';

  @override
  int get carrierHz => 38000;

  // Timing from kElectraAc* in ir_Electra.cpp.
  static const AcTiming _timing = AcTiming(
    leadMark: 9166,
    leadSpace: 4470,
    bitMark: 646,
    oneSpace: 1647,
    zeroSpace: 547,
  );

  // Temperature range/offset (kElectraAcMinTemp/MaxTemp/TempDelta).
  static const int _minTemp = 16;
  static const int _maxTemp = 32;
  static const int _tempDelta = 8;

  // Swing field values (kElectraAcSwingOn / kElectraAcSwingOff). Note these are
  // inverted: 0b000 means swinging, 0b111 means fixed.
  static const int _swingOn = 0x0; // 0b000
  static const int _swingOff = 0x7; // 0b111

  // kElectraAcLightToggleOff — the byte-11 value present in a freshly reset /
  // normally transmitted frame (light not being toggled). Matches the upstream
  // stateReset() so our checksum equals the reference library's.
  static const int _lightToggleOff = 0x08;

  @override
  List<int> encode(AcState state) {
    final bytes = _stateBytes(state);
    return acFrameLsb(bytes, _timing);
  }

  /// Builds the 13 protocol bytes for [s].
  List<int> _stateBytes(AcState s) {
    final b = List<int>.filled(13, 0);

    // byte 0: fixed header constant (stateReset sets raw[0] = 0xC3).
    b[0] = 0xC3;

    // byte 1: SwingV (bits 0-2) + Temp (bits 3-7).
    final temp = s.tempIn(_minTemp, _maxTemp);
    final tempField = (temp - _tempDelta) & 0x1F;
    final swingV = s.swing ? _swingOn : _swingOff;
    b[1] = (swingV & 0x07) | (tempField << 3);

    // byte 2: SwingH (bits 5-7). Our state has a single swing flag; tie the
    // horizontal louver to the same flag so "swing" drives both axes.
    final swingH = s.swing ? _swingOn : _swingOff;
    b[2] = (swingH & 0x07) << 5;

    // byte 4: Fan (bits 5-7).
    b[4] = (_fanBits(s.fan) & 0x07) << 5;

    // byte 6: Mode (bits 5-7).
    b[6] = (_modeBits(s.mode) & 0x07) << 5;

    // byte 9: Power (bit 5).
    if (s.power) b[9] |= 1 << 5;

    // byte 11: LightToggle. Upstream stateReset initialises this to
    // kElectraAcLightToggleOff (0x08) and leaves it there unless the light is
    // explicitly toggled; light is not part of AcState, so we always emit the
    // 0x08 "no toggle" value to match the reference frame and its checksum.
    b[11] = _lightToggleOff;

    // byte 12: checksum = sum of bytes 0..11 (sumBytes over length-1).
    b[12] = acSumChecksum(b.sublist(0, 12));

    return b;
  }

  /// Mode bit values per kElectraAc* constants.
  int _modeBits(AcMode m) => switch (m) {
        AcMode.auto => 0x0, // 0b000
        AcMode.cool => 0x1, // 0b001
        AcMode.dry => 0x2, // 0b010
        AcMode.heat => 0x4, // 0b100
        AcMode.fan => 0x6, // 0b110
      };

  /// Fan bit values per kElectraAcFan* constants.
  int _fanBits(AcFan f) => switch (f) {
        AcFan.auto => 0x5, // 0b101
        AcFan.low => 0x3, // 0b011
        AcFan.medium => 0x2, // 0b010
        AcFan.high => 0x1, // 0b001
      };
}

/// Whirlpool AC IR protocol, ported from IRremoteESP8266
/// `ir_Whirlpool.cpp` / `ir_Whirlpool.h`.
///
/// NOTE ON MODEL: A freshly reset IRWhirlpoolAc defaults to the **DG11J13A**
/// model (the `J191` model bit defaults to 0, and this encoder never sets it).
/// DG11J13A uses a temperature offset of 0, i.e. stored Temp = celsius - 18.
/// (The DG11J191 remote instead uses offset -2 -> celsius - 16, and would
/// require setting the J191 bit in byte 18. We emit DG11J13A frames here, so
/// the displayName / encoding are aligned to that model.)
///
/// Frame = 21 bytes (168 bits) split into 3 sections of {6, 8, 7} bytes, sent
/// LSB-first. Only the FIRST section carries the header/leader; sections 2 and
/// 3 are emitted bare (bit data only), each section terminated by a bit-mark
/// and a gap. Two XOR checksums:
///   * Sum1 (byte 13) = XOR of bytes 2..11   (xorBytes(raw+2, 13-1-2 = 10))
///   * Sum2 (byte 20) = XOR of bytes 14..19  (xorBytes(raw+14, 20-13-1 = 6))
///
/// Timings (us): Hdr 8950/4484, bit mark 597, one 1649, zero 533,
/// inter-section gap 7920, final gap = default message gap (~100000us here).
///
/// Field layout (from the WhirlpoolProtocol union):
///   byte 2: Fan bits[1:0], Power bit2 (TOGGLE), Sleep bit3, Swing1 bit7
///   byte 3: Mode bits[2:0], Temp bits[7:4]  (Temp = celsius - 18)
///   byte 8: OffHours bits[4:0], Swing2 bit6
///   byte 13: Sum1   byte 15: Cmd   byte 20: Sum2
///
/// stateReset() base: raw[0]=0x83, raw[1]=0x06, raw[6]=0x80, rest 0.
/// (byte 6 is ClockHours[4:0], LightOff bit5, pad bits6-7; 0x80 is a pad bit
/// and is replicated verbatim from stateReset().)
class WhirlpoolAcAcEncoder implements AcIrEncoder {
  @override
  String get brandId => 'whirlpool_ac';

  @override
  String get displayName => 'Whirlpool AC (DG11J13A)';

  @override
  int get carrierHz => 38000;

  // --- Timing constants (us), verbatim from ir_Whirlpool.cpp ---
  static const int _hdrMark = 8950;
  static const int _hdrSpace = 4484;
  static const int _bitMark = 597;
  static const int _oneSpace = 1649;
  static const int _zeroSpace = 533;
  static const int _gap = 7920; // kWhirlpoolAcGap, between sections
  static const int _minGap = 100000; // kWhirlpoolAcMinGap (kDefaultMessageGap)

  // --- Protocol enum values (ir_Whirlpool.h) ---
  static const int _modeHeat = 0;
  static const int _modeAuto = 1;
  static const int _modeCool = 2;
  static const int _modeDry = 3;
  static const int _modeFan = 4;

  static const int _fanAuto = 0;
  static const int _fanHigh = 1;
  static const int _fanMedium = 2;
  static const int _fanLow = 3;

  static const int _minTemp = 18; // kWhirlpoolAcMinTemp (offset 0 for DG11J13A)
  static const int _maxTemp = 30; // app range cap (proto max is 32)

  // Command code written into byte 15. We always send a full state; the most
  // representative "this is a settings change" command is Mode (0x06).
  static const int _cmdMode = 0x06; // kWhirlpoolAcCommandMode

  @override
  List<int> encode(AcState state) {
    final raw = _stateBytes(state);

    final out = <int>[];

    // Section 1: bytes 0..5, WITH header/leader, terminated by mark + gap.
    out.add(_hdrMark);
    out.add(_hdrSpace);
    _emitBytes(out, raw, 0, 6);
    out.add(_bitMark);
    out.add(_gap);

    // Section 2: bytes 6..13 (8 bytes), no header, mark + gap.
    _emitBytes(out, raw, 6, 14);
    out.add(_bitMark);
    out.add(_gap);

    // Section 3: bytes 14..20 (7 bytes), no header, final mark + min gap.
    _emitBytes(out, raw, 14, 21);
    out.add(_bitMark);
    out.add(_minGap);

    return out;
  }

  /// Appends bytes [start, end) of [raw] as LSB-first pulse-distance pairs.
  void _emitBytes(List<int> out, List<int> raw, int start, int end) {
    for (var bi = start; bi < end; bi++) {
      final b = raw[bi];
      for (var i = 0; i < 8; i++) {
        out.add(_bitMark);
        out.add(((b >> i) & 1) == 1 ? _oneSpace : _zeroSpace);
      }
    }
  }

  /// Builds the 21 protocol bytes from [s], following the WhirlpoolProtocol
  /// union layout and the stateReset() base, then writes both XOR checksums.
  List<int> _stateBytes(AcState s) {
    final raw = List<int>.filled(21, 0);

    // stateReset() base values.
    raw[0] = 0x83;
    raw[1] = 0x06;
    raw[6] = 0x80;

    // byte 2: Fan[1:0], Power bit2 (toggle), Sleep bit3, Swing1 bit7.
    raw[2] = _fanBits(s.fan) & 0x03;
    if (s.power) raw[2] |= 1 << 2; // Power is a TOGGLE on this protocol.
    if (s.swing) raw[2] |= 1 << 7; // Swing1.

    // byte 3: Mode[2:0], Temp[7:4]. Temp encoded as celsius - 18 (DG11J13A).
    final t = s.temp.clamp(_minTemp, _maxTemp);
    raw[3] = (_modeBits(s.mode) & 0x07) | (((t - _minTemp) & 0x0F) << 4);

    // byte 8: OffHours[4:0], (pad bit5), Swing2 bit6 (mirrors Swing1 per
    // setSwing()).
    if (s.swing) raw[8] |= 1 << 6;

    // byte 15: Cmd (which setting changed). Full state is always present.
    raw[15] = _cmdMode;

    // --- Checksums (XOR) ---
    // Sum1 @ byte 13 = XOR of bytes 2..11 (xorBytes(raw+2, 10)).
    var sum1 = 0;
    for (var i = 2; i < 12; i++) {
      sum1 ^= raw[i];
    }
    raw[13] = sum1 & 0xFF;

    // Sum2 @ byte 20 = XOR of bytes 14..19 (xorBytes(raw+14, 6)).
    var sum2 = 0;
    for (var i = 14; i < 20; i++) {
      sum2 ^= raw[i];
    }
    raw[20] = sum2 & 0xFF;

    return raw;
  }

  int _modeBits(AcMode m) => switch (m) {
        AcMode.heat => _modeHeat,
        AcMode.auto => _modeAuto,
        AcMode.cool => _modeCool,
        AcMode.dry => _modeDry,
        AcMode.fan => _modeFan,
      };

  int _fanBits(AcFan f) => switch (f) {
        AcFan.auto => _fanAuto,
        AcFan.high => _fanHigh,
        AcFan.medium => _fanMedium,
        AcFan.low => _fanLow,
      };
}

/// Sharp AC air-conditioner IR encoder.
///
/// Ported faithfully from IRremoteESP8266 `ir_Sharp.cpp` / `ir_Sharp.h`
/// (the `kSharpAc*` protocol): a 13-byte / 104-bit pulse-distance frame sent
/// LSB-first, with a nibble-folded XOR checksum in the high nibble of the last
/// byte.
///
/// We start from the library's verified "known good" reset state and overwrite
/// only the fields our [AcState] models (power / temp / mode / fan / swing),
/// leaving every model/constant byte untouched so the frame stays valid.
class SharpAcAcEncoder implements AcIrEncoder {
  const SharpAcAcEncoder();

  @override
  String get brandId => 'sharp_ac';

  @override
  String get displayName => 'Sharp AC';

  @override
  int get carrierHz => 38000;

  // --- Timings (microseconds), from ir_Sharp.h ---
  static const int _hdrMark = 3800; // kSharpAcHdrMark
  static const int _hdrSpace = 1900; // kSharpAcHdrSpace
  static const int _bitMark = 470; // kSharpAcBitMark
  static const int _oneSpace = 1400; // kSharpAcOneSpace
  static const int _zeroSpace = 500; // kSharpAcZeroSpace
  static const int _gap = 100000; // kDefaultMessageGap (inter-frame gap)

  // --- Layout constants, from ir_Sharp.h ---
  static const int _minTemp = 15; // kSharpAcMinTemp
  static const int _maxTemp = 30; // kSharpAcMaxTemp

  // PowerSpecial (byte 5, high nibble) values.
  static const int _powerOnFromOff = 1; // kSharpAcPowerOnFromOff
  static const int _powerOff = 2; // kSharpAcPowerOff

  // Mode (byte 6, bits 0-1) values.
  static const int _modeAuto = 0x0; // kSharpAcAuto (also kSharpAcFan)
  static const int _modeHeat = 0x1; // kSharpAcHeat
  static const int _modeCool = 0x2; // kSharpAcCool
  static const int _modeDry = 0x3; // kSharpAcDry

  // Fan (byte 6, bits 4-6) values.
  static const int _fanAuto = 0x2; // kSharpAcFanAuto
  static const int _fanMin = 0x4; // kSharpAcFanMin  (low)
  static const int _fanMed = 0x3; // kSharpAcFanMed  (medium)
  static const int _fanHigh = 0x5; // kSharpAcFanHigh (high)

  // Swing (byte 8, bits 0-2) values.
  static const int _swingOff = 0x2; // kSharpAcSwingVOff
  static const int _swingToggle = 0x7; // kSharpAcSwingVToggle (request swing)

  // Special (byte 10).
  static const int _specialPower = 0x00; // kSharpAcSpecialPower

  /// The library's known-good 13-byte reset state. All constant/model bytes
  /// come from here; only mutable fields are overwritten below.
  static const List<int> _reset = <int>[
    0xAA, 0x5A, 0xCF, 0x10, 0x00, 0x01, 0x00, 0x00, 0x08, 0x80, 0x00, 0xE0,
    0x01, //
  ];

  @override
  List<int> encode(AcState state) {
    final s = List<int>.of(_reset);

    // Temp: byte 4, bits 0-3 = degrees - minTemp.
    final temp = state.tempIn(_minTemp, _maxTemp);
    s[4] = (s[4] & 0xF0) | ((temp - _minTemp) & 0x0F);

    // PowerSpecial: byte 5, bits 4-7.
    final power = state.power ? _powerOnFromOff : _powerOff;
    s[5] = (s[5] & 0x0F) | ((power & 0x0F) << 4);

    // Mode: byte 6, bits 0-1.
    final mode = switch (state.mode) {
      AcMode.auto => _modeAuto,
      AcMode.heat => _modeHeat,
      AcMode.cool => _modeCool,
      AcMode.dry => _modeDry,
      AcMode.fan => _modeAuto, // kSharpAcFan == kSharpAcAuto (0b00)
    };
    // Fan: byte 6, bits 4-6.
    final fan = switch (state.fan) {
      AcFan.auto => _fanAuto,
      AcFan.low => _fanMin,
      AcFan.medium => _fanMed,
      AcFan.high => _fanHigh,
    };
    s[6] = (s[6] & 0x88) | (mode & 0x03) | ((fan & 0x07) << 4);

    // Swing: byte 8, bits 0-2.
    final swing = state.swing ? _swingToggle : _swingOff;
    s[8] = (s[8] & 0xF8) | (swing & 0x07);

    // Special: byte 10 — act on the power/state change.
    s[10] = _specialPower;

    // Checksum: byte 12, high nibble.
    s[12] = (s[12] & 0x0F) | ((_calcChecksum(s) & 0x0F) << 4);

    return _frame(s);
  }

  /// Sharp's nibble-folded XOR checksum (ir_Sharp.cpp `calcChecksum`):
  /// xor of all bytes except the last, xor the last byte's low nibble, then
  /// fold the high nibble into the low nibble; return the low nibble.
  int _calcChecksum(List<int> state) {
    var xorsum = 0;
    for (var i = 0; i < state.length - 1; i++) {
      xorsum ^= state[i] & 0xFF;
    }
    xorsum ^= state[state.length - 1] & 0x0F; // low nibble of last byte
    xorsum ^= (xorsum >> 4) & 0x0F; // fold high nibble into low
    return xorsum & 0x0F;
  }

  /// LSB-first pulse-distance frame: leader, 13 bytes, trailing stop mark + gap.
  List<int> _frame(List<int> bytes) {
    final out = <int>[_hdrMark, _hdrSpace];
    for (final b in bytes) {
      for (var i = 0; i < 8; i++) {
        out.add(_bitMark);
        out.add(((b >> i) & 1) == 1 ? _oneSpace : _zeroSpace);
      }
    }
    out.add(_bitMark); // stop bit
    out.add(_gap); // inter-message gap
    return out;
  }
}
