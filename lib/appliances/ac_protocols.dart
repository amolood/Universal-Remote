/// Shared helpers for the stateful air-conditioner IR protocols.
///
/// Each manufacturer transmits the FULL desired state (power/temp/mode/fan/
/// swing) in every frame, with a brand-specific byte layout and checksum. The
/// per-brand encoders in this file translate an [AcState] into that brand's
/// bytes (ported from the verified IRremoteESP8266 layouts — see
/// docs/ir_protocols_research.md) and then frame them as IR pulses.
library;

import 'appliance.dart';

/// Pulse-distance frame timing for a byte-oriented AC protocol.
class AcTiming {
  final int leadMark;
  final int leadSpace;
  final int bitMark;
  final int oneSpace;
  final int zeroSpace;

  /// Optional gap+lead repeated between sections (0 = single section).
  final int sectionGap;

  const AcTiming({
    required this.leadMark,
    required this.leadSpace,
    required this.bitMark,
    required this.oneSpace,
    required this.zeroSpace,
    this.sectionGap = 0,
  });
}

/// Emits [bytes] LSB-first as a pulse-distance burst with [t], framed by a
/// leader and a trailing stop mark. Most AC protocols send each byte LSB-first.
List<int> acFrameLsb(List<int> bytes, AcTiming t) {
  final out = <int>[t.leadMark, t.leadSpace];
  for (final b in bytes) {
    for (var i = 0; i < 8; i++) {
      out.add(t.bitMark);
      out.add(((b >> i) & 1) == 1 ? t.oneSpace : t.zeroSpace);
    }
  }
  out.add(t.bitMark); // stop
  return out;
}

/// Two-section frame: [section1] and [section2] each get their own leader, with
/// [t.sectionGap] between, both LSB-first. Used by Panasonic/Samsung/Whirlpool.
List<int> acFrameTwoSection(List<int> s1, List<int> s2, AcTiming t) {
  final out = <int>[];
  out.addAll(acFrameLsb(s1, t));
  if (t.sectionGap > 0) out.add(t.sectionGap);
  out.addAll(acFrameLsb(s2, t));
  return out;
}

/// Common numeric views of [AcState] shared across brand encoders.
extension AcStateFields on AcState {
  /// Temperature clamped to a brand range [lo]..[hi].
  int tempIn(int lo, int hi) => temp.clamp(lo, hi);
}

/// Sum of all bytes, masked to 8 bits (additive checksum). Common pattern.
int acSumChecksum(List<int> bytes, {int init = 0}) {
  var sum = init;
  for (final b in bytes) {
    sum += b;
  }
  return sum & 0xFF;
}

/// XOR of all bytes (XOR checksum). Used by Toshiba.
int acXorChecksum(List<int> bytes, {int init = 0}) {
  var x = init;
  for (final b in bytes) {
    x ^= b;
  }
  return x & 0xFF;
}

/// Sum of every nibble (low + high of each byte), masked to 8 bits.
int acNibbleSum(List<int> bytes, {int init = 0}) {
  var sum = init;
  for (final b in bytes) {
    sum += (b & 0x0F) + ((b >> 4) & 0x0F);
  }
  return sum & 0xFF;
}
