import 'dart:typed_data';

import 'package:atv_remote/atv/certificate.dart';
import 'package:atv_remote/atv/pairing_secret.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/sha256.dart';

void main() {
  test('cert generation -> modulus/exponent round trips', () {
    final cert = ClientCertificate.generate();

    final fromPriv = clientModExpFromPrivatePem(cert.privateKeyPem);
    final fromCert = RsaModExp.fromCertificatePem(cert.certificatePem);

    expect(fromCert.modulus, equals(fromPriv.modulus));
    expect(fromCert.exponent, equals(fromPriv.exponent));
    expect(fromPriv.exponent, equals(BigInt.from(65537)));
    // 2048-bit modulus is 256 bytes => 512 hex chars.
    expect(fromPriv.modulus.toRadixString(16).length, inInclusiveRange(510, 512));
  });

  test('secret matches reference algorithm and verifies check byte', () {
    // Use two generated identities as "client" and "server".
    final client = clientModExpFromPrivatePem(
        ClientCertificate.generate().privateKeyPem);
    final server = clientModExpFromPrivatePem(
        ClientCertificate.generate().privateKeyPem);

    // Independently compute what the hash digest's first byte is for a chosen
    // 4-hex tail, then build a 6-char code whose first 2 chars match it.
    final tail = 'a1b2';
    final h = SHA256Digest();
    void upd(String hex) {
      final b = _hexToBytes(hex);
      h.update(b, 0, b.length);
    }

    String modHex(BigInt n) {
      var s = n.toRadixString(16).toUpperCase();
      if (s.length.isOdd) s = '0$s';
      return s;
    }

    upd(modHex(client.modulus));
    upd('0${client.exponent.toRadixString(16).toUpperCase()}');
    upd(modHex(server.modulus));
    upd('0${server.exponent.toRadixString(16).toUpperCase()}');
    upd(tail);
    final out = Uint8List(32);
    h.doFinal(out, 0);
    final checkByte = out[0].toRadixString(16).padLeft(2, '0');
    final code = '$checkByte$tail';

    // Now PairingSecret.compute should accept this exact code and return out.
    final secret = PairingSecret.compute(
      client: client,
      server: server,
      code: code,
    );
    expect(secret, equals(out));

    // A wrong check byte must be rejected.
    final wrong = (out[0] ^ 0xFF).toRadixString(16).padLeft(2, '0') + tail;
    expect(
      () => PairingSecret.compute(client: client, server: server, code: wrong),
      throwsA(isA<PairingCodeError>()),
    );
  });
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
