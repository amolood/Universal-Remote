import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'certificate.dart';

/// Computes the pairing secret exactly as the reference Android TV remote
/// implementations do.
///
/// Reference (androidtvremote2/pairing.py):
///   h = sha256()
///   h.update(bytes.fromhex(f"{client_modulus:X}"))
///   h.update(bytes.fromhex(f"0{client_exponent:X}"))
///   h.update(bytes.fromhex(f"{server_modulus:X}"))
///   h.update(bytes.fromhex(f"0{server_exponent:X}"))
///   h.update(bytes.fromhex(pairing_code[2:]))
///   hash = h.digest()
///   assert hash[0] == int(pairing_code[0:2], 16)
///   secret = hash
class PairingSecret {
  /// Builds the secret to send back, after verifying the typed [code]
  /// (6 hex characters shown on the TV) matches the certificates.
  ///
  /// Throws [PairingCodeError] if the code's check byte does not match.
  static Uint8List compute({
    required RsaModExp client,
    required RsaModExp server,
    required String code,
  }) {
    final normalized = code.trim();
    if (normalized.length != 6) {
      throw const PairingCodeError('Pairing code must be 6 hex characters');
    }
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
      throw const PairingCodeError('Pairing code must be hexadecimal');
    }

    final h = SHA256Digest();
    _update(h, _modulusHex(client.modulus));
    _update(h, _exponentHex(client.exponent));
    _update(h, _modulusHex(server.modulus));
    _update(h, _exponentHex(server.exponent));
    // bytes.fromhex(pairing_code[2:]) — the last 4 hex chars (2 bytes).
    _update(h, normalized.substring(2));

    final out = Uint8List(32);
    h.doFinal(out, 0);

    // hash[0] must equal int(code[0:2], 16).
    final expected = int.parse(normalized.substring(0, 2), radix: 16);
    if (out[0] != expected) {
      throw const PairingCodeError(
          'Wrong pairing code (hash mismatch). Re-check the code on the TV.');
    }
    return out;
  }

  static void _update(SHA256Digest h, String hex) {
    final b = _hexToBytes(hex);
    h.update(b, 0, b.length);
  }

  /// Replicates Python's `f"{n:X}"` then `bytes.fromhex(...)`.
  /// `{n:X}` produces uppercase hex with NO leading zero; bytes.fromhex
  /// requires an even number of nibbles. For a normal 2048-bit modulus this
  /// is already 512 chars (even). If it were ever odd, Python would raise —
  /// so we mirror that by requiring even length (it always is in practice).
  static String _modulusHex(BigInt n) {
    var s = n.toRadixString(16).toUpperCase();
    // bytes.fromhex needs even length; {n:X} for a top-bit-set modulus is even.
    if (s.length.isOdd) s = '0$s';
    return s;
  }

  /// Replicates Python's `f"0{e:X}"` — exponent prefixed with a literal '0'.
  /// For e=65537 -> "0" + "10001" = "010001" (3 bytes: 01 00 01).
  static String _exponentHex(BigInt e) {
    return '0${e.toRadixString(16).toUpperCase()}';
  }

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

class PairingCodeError implements Exception {
  final String message;
  const PairingCodeError(this.message);
  @override
  String toString() => message;
}
