/// Low-level IR protocol frame builders for the key-based TV/AV remotes.
///
/// Each function returns a raw burst as a list of microsecond mark/space
/// durations (starting with a mark), ready for the phone IR emitter or a Wi-Fi
/// IR hub. Timings are taken from the verified protocol research
/// (docs/ir_protocols_research.md), cross-checked against IRremoteESP8266.
///
/// These build *frames*; the per-brand encoders in device_ir_encoder.dart pick
/// the protocol, addresses, and per-button command codes.
library;

/// Appends [bits] (LSB-first) as pulse-distance bits to [out]: each bit is a
/// [bitMark] mark followed by [oneSpace] (1) or [zeroSpace] (0) space.
void _addBitsLsb(List<int> out, int value, int nbits, int bitMark,
    int oneSpace, int zeroSpace) {
  for (var i = 0; i < nbits; i++) {
    out.add(bitMark);
    out.add(((value >> i) & 1) == 1 ? oneSpace : zeroSpace);
  }
}

// ============================ NEC (32-bit) ============================

/// NEC family, 38kHz. Leader 9000/4500, 560 bit mark, 0-space 560, 1-space 1690,
/// trailing stop mark. 32 bits LSB-first.
///
/// [raw32] is the full 32-bit word (addr, addr2, cmd, cmd2 packed by the
/// caller) — this lets callers emit standard NEC (cmd2 = ~cmd) or extended NEC
/// (non-inverted address/command, e.g. Hisense) without this builder caring.
class NecProtocol {
  static const carrierHz = 38000;
  static const _lead = [9000, 4500];
  static const _bitMark = 560;
  static const _oneSpace = 1690;
  static const _zeroSpace = 560;

  /// Builds a frame from a pre-assembled 32-bit word (transmitted LSB-first).
  static List<int> raw(int word32) {
    final out = <int>[..._lead];
    _addBitsLsb(out, word32, 32, _bitMark, _oneSpace, _zeroSpace);
    out.add(_bitMark); // stop
    return out;
  }

  /// Standard NEC: 8-bit [address] + ~address + 8-bit [command] + ~command.
  static List<int> standard(int address, int command) {
    final word = (address & 0xFF) |
        (((~address) & 0xFF) << 8) |
        ((command & 0xFF) << 16) |
        (((~command) & 0xFF) << 24);
    return raw(word);
  }

  /// Extended NEC: 16-bit [address] (not inverted) + 8-bit [command] +
  /// ~command. Used by sets with a fixed 16-bit address (e.g. Hisense, TCL).
  static List<int> extended(int address16, int command) {
    final word = (address16 & 0xFFFF) |
        ((command & 0xFF) << 16) |
        (((~command) & 0xFF) << 24);
    return raw(word);
  }
}

// ============================ Samsung (32-bit) ============================

/// Samsung32, 38kHz. Symmetric leader 4480/4480, 560 bit mark, 0-space 560,
/// 1-space 1680, stop mark. 32 bits LSB-first = customer + customer + cmd +
/// ~cmd (address byte duplicated, NOT inverted — the key NEC distinction).
class SamsungProtocol {
  static const carrierHz = 38000;
  static const _lead = [4480, 4480];
  static const _bitMark = 560;
  static const _oneSpace = 1680;
  static const _zeroSpace = 560;

  static List<int> frame(int customer, int command) {
    final word = (customer & 0xFF) |
        ((customer & 0xFF) << 8) |
        ((command & 0xFF) << 16) |
        (((~command) & 0xFF) << 24);
    final out = <int>[..._lead];
    _addBitsLsb(out, word, 32, _bitMark, _oneSpace, _zeroSpace);
    out.add(_bitMark);
    return out;
  }
}

// ============================ Sony SIRC ============================

/// Sony SIRC, **40kHz** (not 38). Pulse-WIDTH coded: start 2400 mark + 600
/// space; each bit = 1200 mark ('1') or 600 mark ('0') + 600 space. LSB-first.
/// 12/15/20-bit variants. Caller must send the frame ≥3× (handled by the
/// encoder layer via [repeats]).
class SonyProtocol {
  static const carrierHz = 40000;
  static const _startMark = 2400;
  static const _space = 600;
  static const _oneMark = 1200;
  static const _zeroMark = 600;

  /// One SIRC frame: [command] (7 bits) then [address] (deviceBits wide),
  /// LSB-first. [bits] is total (12/15/20). For 12-bit, deviceBits = 5.
  static List<int> _oneFrame(int command, int address, int bits) {
    final out = <int>[_startMark, _space];
    final cmdBits = 7;
    final addrBits = bits - cmdBits;
    // command (7 bits, LSB-first)
    for (var i = 0; i < cmdBits; i++) {
      out.add(((command >> i) & 1) == 1 ? _oneMark : _zeroMark);
      out.add(_space);
    }
    // address (remaining bits, LSB-first)
    for (var i = 0; i < addrBits; i++) {
      out.add(((address >> i) & 1) == 1 ? _oneMark : _zeroMark);
      out.add(_space);
    }
    return out;
  }

  /// SIRC frame repeated [repeats] times (Sony needs ≥3). 12-bit default.
  static List<int> frame(int command, int address,
      {int bits = 12, int repeats = 3}) {
    final out = <int>[];
    for (var r = 0; r < repeats; r++) {
      out.addAll(_oneFrame(command, address, bits));
    }
    return out;
  }
}

// ======================= Kaseikyo / Panasonic (48-bit) =======================

/// Kaseikyo (Panasonic), **37kHz**. Pulse-distance, unit 432. Leader 3456/1728,
/// 432 bit mark, 1-space 1296, 0-space 432, stop. 48 bits LSB-first = 16-bit
/// vendor + 8 device + 8 subdevice + 8 command + 8 checksum (dev^sub^cmd).
class KaseikyoProtocol {
  static const carrierHz = 37000;
  static const _lead = [3456, 1728];
  static const _bitMark = 432;
  static const _oneSpace = 1296;
  static const _zeroSpace = 432;

  /// Panasonic vendor id (little-endian 0x2002 sent as bytes 0x02,0x20).
  static const panasonicVendor = 0x2002;

  static List<int> frame(int vendor, int device, int subdevice, int command) {
    final checksum = (device ^ subdevice ^ command) & 0xFF;
    final out = <int>[..._lead];
    _addBitsLsb(out, vendor & 0xFFFF, 16, _bitMark, _oneSpace, _zeroSpace);
    _addBitsLsb(out, device & 0xFF, 8, _bitMark, _oneSpace, _zeroSpace);
    _addBitsLsb(out, subdevice & 0xFF, 8, _bitMark, _oneSpace, _zeroSpace);
    _addBitsLsb(out, command & 0xFF, 8, _bitMark, _oneSpace, _zeroSpace);
    _addBitsLsb(out, checksum, 8, _bitMark, _oneSpace, _zeroSpace);
    out.add(_bitMark);
    return out;
  }
}

// ============================ RC5 / RC6 (Philips) ============================

/// Philips RC5, **36kHz**. Manchester-coded, 889us half-bit (1778 bit time).
/// 14 bits: 2 start (1,1) + toggle + 5 address + 6 command, MSB-first. No
/// leader. A logical 1 = space→mark, 0 = mark→space (IEEE 802.3 convention).
class Rc5Protocol {
  static const carrierHz = 36000;
  static const _half = 889;

  /// [toggle] flips on each successive keypress (caller manages it; 0/1).
  static List<int> frame(int address, int command, {int toggle = 0}) {
    // 14-bit word: S1=1, S2=1, T, A4..A0, C5..C0  (MSB-first).
    final word = (1 << 13) |
        (1 << 12) |
        ((toggle & 1) << 11) |
        ((address & 0x1F) << 6) |
        (command & 0x3F);
    // Manchester: build a level sequence then collapse to mark/space runs.
    // RC5 bit '1' = low(889) then high(889); '0' = high then low. We emit IR
    // "mark" for the high (carrier-on) half. Track carrier on/off transitions.
    final levels = <bool>[]; // true = carrier on (mark)
    for (var i = 13; i >= 0; i--) {
      final bit = (word >> i) & 1;
      if (bit == 1) {
        levels.add(false); // first half off
        levels.add(true); // second half on
      } else {
        levels.add(true);
        levels.add(false);
      }
    }
    return _collapse(levels, _half);
  }

  /// Collapses a half-bit level sequence into mark/space durations. The burst
  /// must start with a mark; a leading "off" half is dropped (RC5 always starts
  /// with the S1=1 bit, whose first half is off then on — so the real first
  /// mark is the second half). We normalise so output[0] is a mark.
  static List<int> _collapse(List<bool> levels, int half) {
    // Drop leading off-halves so we begin on a mark.
    var start = 0;
    while (start < levels.length && !levels[start]) {
      start++;
    }
    final out = <int>[];
    var i = start;
    while (i < levels.length) {
      final on = levels[i];
      var run = 0;
      while (i < levels.length && levels[i] == on) {
        run += half;
        i++;
      }
      // Output marks and spaces alternately; the first run is a mark (on).
      out.add(run);
    }
    return out;
  }
}

/// Philips RC6 mode 0, **36kHz**. Leader 2666 mark + 889 space; base time 444;
/// 20 bits with a double-width toggle bit; Manchester but inverted sense vs RC5.
class Rc6Protocol {
  static const carrierHz = 36000;
  static const _leadMark = 2666;
  static const _leadSpace = 889;
  static const _base = 444;

  static List<int> frame(int address, int command, {int toggle = 0}) {
    // Mode-0 RC6: start bit (1) + 3 mode bits (000) + toggle(double) +
    // 8 address + 8 command, MSB-first. RC6 '1' = mark→space, '0' = space→mark
    // (inverted vs RC5).
    final levels = <bool>[]; // true = mark
    void addBit(int bit, {bool dbl = false}) {
      final unit = dbl ? 2 : 1;
      if (bit == 1) {
        for (var k = 0; k < unit; k++) {
          levels.add(true);
        }
        for (var k = 0; k < unit; k++) {
          levels.add(false);
        }
      } else {
        for (var k = 0; k < unit; k++) {
          levels.add(false);
        }
        for (var k = 0; k < unit; k++) {
          levels.add(true);
        }
      }
    }

    addBit(1); // start bit
    for (var i = 2; i >= 0; i--) {
      addBit(0); // mode 000
    }
    addBit(toggle & 1, dbl: true); // toggle, double width
    for (var i = 7; i >= 0; i--) {
      addBit((address >> i) & 1);
    }
    for (var i = 7; i >= 0; i--) {
      addBit((command >> i) & 1);
    }

    final out = <int>[_leadMark, _leadSpace];
    // Collapse half-units (base time each) starting from a mark.
    var i = 0;
    // The leader space already placed; the first level should continue from a
    // space, so if it's a mark we start a fresh run, else merge into the space.
    var pendingSpaceExtra = 0;
    if (levels.isNotEmpty && !levels[0]) {
      // leading space half merges with leader space
      var run = 0;
      while (i < levels.length && !levels[i]) {
        run += _base;
        i++;
      }
      pendingSpaceExtra = run;
    }
    if (pendingSpaceExtra > 0) {
      out[1] = out[1] + pendingSpaceExtra;
    }
    while (i < levels.length) {
      final on = levels[i];
      var run = 0;
      while (i < levels.length && levels[i] == on) {
        run += _base;
        i++;
      }
      out.add(run);
    }
    return out;
  }
}

// ============================ Sharp (15-bit) ============================

/// Sharp, 38kHz. No leader; 260 bit mark; 0-space 780, 1-space 1820. 15 bits
/// LSB-first = addr(5) + cmd(8) + expansion(1) + check(1). Frame sent twice;
/// the second has cmd/expansion/check inverted.
class SharpProtocol {
  static const carrierHz = 38000;
  static const _bitMark = 260;
  static const _oneSpace = 1820;
  static const _zeroSpace = 780;
  static const _gap = 40000; // inter-frame gap

  static List<int> _oneFrame(int address, int command, int expansion, int check) {
    final word = (address & 0x1F) |
        ((command & 0xFF) << 5) |
        ((expansion & 1) << 13) |
        ((check & 1) << 14);
    final out = <int>[];
    _addBitsLsb(out, word, 15, _bitMark, _oneSpace, _zeroSpace);
    out.add(_bitMark); // stop
    return out;
  }

  /// Full Sharp transmission: first frame (expansion=1, check=0) then, after a
  /// gap, the inverted-check frame (expansion=0, check=1, command inverted).
  static List<int> frame(int address, int command) {
    final out = <int>[];
    out.addAll(_oneFrame(address, command, 1, 0));
    out.add(_gap);
    out.addAll(_oneFrame(address, (~command) & 0xFF, 0, 1));
    return out;
  }
}
