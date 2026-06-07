/// Decodes a CVTE/Bytello PIN code into the TV's IP address and WebSocket port.
///
/// Ported from the Bytello app's RemotePinCode (`g.java`) + RemoteApi.d().
/// The PIN encodes everything needed to connect — there is no key exchange.
///
/// Encoding:
///   - The code is Base32 over the alphabet "0123456789ABCDEFGHIJKLMNOPQRSTUV",
///     with 'W'->'0' and 'X'->'1' substitutions, decoded to a binary string,
///     then left-padded with '0' to 30 bits.
///   - bits[0:2] select the subnet family: "00"->10.x, "01"->172.x.x, "10"->192.168.x
///   - subsequent 8-bit groups are the remaining octets (parsed as binary)
///   - the port maps from a small table by a 2-bit selector (default 8125).
class CvtePin {
  static const _alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUV';

  // selector(2 bits) -> port
  static const Map<String, int> _ports = {
    '00': 8125,
    '01': 8126,
    '10': 8127,
    '11': 8128,
  };

  /// Returns (host, port), or null if the code can't be decoded / fails its
  /// internal checksum.
  static (String host, int port)? decode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final bits = _padLeft(_base32ToBinary(normalized), 30, '0');
    if (bits.length < 30) return null;

    final family = bits.substring(0, 2);

    // Checksum: a 2-char prefix-derived check compared against a fold of the
    // payload tail (mirrors g.c() in the app). We validate but stay lenient.
    if (!_verify(bits, family)) return null;

    // Port selector lives in bits[2:4] for "00"/"01" families, [12:14] for "10".
    final String portSel;
    final String host;
    switch (family) {
      case '00': // 10.a.b.c
        portSel = bits.substring(4, 6);
        final body = bits.substring(6, 30);
        host = '10.${_oct(body, 0)}.${_oct(body, 8)}.${_oct(body, 16)}';
        break;
      case '01': // 172.a.b.c
        portSel = bits.substring(4, 6);
        final body = bits.substring(6, 30);
        host = '172.${_oct(body, 0)}.${_oct(body, 8)}.${_oct(body, 16)}';
        break;
      case '10': // 192.168.a.b
        portSel = bits.substring(12, 14);
        final body = bits.substring(14, 30);
        host = '192.168.${_oct(body, 0)}.${_oct(body, 8)}';
        break;
      default:
        return null;
    }

    final port = _ports[portSel] ?? 8125;
    return (host, port);
  }

  static int _oct(String body, int start) =>
      int.parse(body.substring(start, start + 8), radix: 2);

  /// Base32 -> binary string (BigInt to handle long codes), with W/X swaps.
  static String _base32ToBinary(String code) {
    final s = code.replaceAll('W', '0').replaceAll('X', '1');
    BigInt value = BigInt.zero;
    for (final ch in s.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) continue; // skip unknowns
      value = value * BigInt.from(32) + BigInt.from(idx);
    }
    return value.toRadixString(2);
  }

  static String _padLeft(String s, int len, String pad) =>
      s.length >= len ? s : (pad * (len - s.length)) + s;

  /// Lenient checksum mirror of g.c(): folds head+tail halves. Returns true
  /// when the embedded check matches; on any structural surprise, returns true
  /// to avoid blocking otherwise-valid codes from slightly different firmware.
  static bool _verify(String bits, String family) {
    try {
      switch (family) {
        case '00':
        case '01':
          final check = bits.substring(2, 4);
          final body = bits.substring(6, 30);
          return check == _fold(2, body);
        case '10':
          final check = bits.substring(2, 12);
          final body = bits.substring(14, 30);
          return check == _fold(10, body);
        default:
          return false;
      }
    } catch (_) {
      return true;
    }
  }

  /// g.c(n, s): first n/2 chars + last n/2 chars of s.
  static String _fold(int n, String s) {
    final half = n ~/ 2;
    if (s.length < n) return s;
    return s.substring(0, half) + s.substring(s.length - half);
  }
}
