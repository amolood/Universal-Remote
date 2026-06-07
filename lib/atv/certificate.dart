import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:basic_utils/basic_utils.dart';

/// A generated client identity: an RSA keypair and a self-signed X.509
/// certificate, both in PEM form, used as the TLS client certificate when
/// talking to the Android TV.
class ClientCertificate {
  final String privateKeyPem;
  final String certificatePem;

  ClientCertificate(this.privateKeyPem, this.certificatePem);

  /// Generates a fresh 2048-bit RSA keypair and a self-signed certificate.
  /// The TV does not validate the certificate contents, only that a client
  /// cert is presented and used consistently across pairing + control.
  static ClientCertificate generate() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;

    final dn = {
      'CN': 'atvremote',
      'O': 'Android TV Remote',
      'C': 'US',
    };

    final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);
    final certPem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      9125, // ~25 years
    );

    final privPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
    return ClientCertificate(privPem, certPem);
  }
}

/// The modulus (n) and public exponent (e) of an RSA public key, used to
/// build the pairing secret hash.
class RsaModExp {
  final BigInt modulus;
  final BigInt exponent;
  RsaModExp(this.modulus, this.exponent);

  /// Parses a PEM-encoded X.509 certificate and extracts its RSA public key
  /// numbers.
  static RsaModExp fromCertificatePem(String pem) {
    return fromCertificateDer(_pemToDer(pem));
  }

  /// Extracts the RSA modulus/exponent directly from a certificate's DER bytes.
  ///
  /// This walks the ASN.1 tree itself (via asn1lib) instead of going through
  /// basic_utils' high-level X.509 parser, which throws "Bad element" on some
  /// real TV certificates whose structure it doesn't expect. We locate the
  /// SubjectPublicKeyInfo robustly: the BIT STRING whose unwrapped contents are
  /// `SEQUENCE { INTEGER modulus, INTEGER exponent }`.
  static RsaModExp fromCertificateDer(Uint8List certDer) {
    final root = ASN1Parser(certDer).nextObject();
    final found = _findRsaKey(root);
    if (found == null) {
      throw const FormatException(
          'Could not locate an RSA public key in the certificate');
    }
    return found;
  }

  /// Depth-first search for the SubjectPublicKeyInfo's RSA key.
  static RsaModExp? _findRsaKey(ASN1Object node) {
    if (node is ASN1Sequence) {
      // Direct case: SEQ { INTEGER, INTEGER } is an RSAPublicKey.
      if (node.elements.length == 2 &&
          node.elements[0] is ASN1Integer &&
          node.elements[1] is ASN1Integer) {
        final n = (node.elements[0] as ASN1Integer).valueAsBigInteger;
        final e = (node.elements[1] as ASN1Integer).valueAsBigInteger;
        // Heuristic: a real modulus is large; exponent is small. Avoids
        // misreading other 2-INTEGER sequences (e.g. validity, serials).
        if (n.bitLength >= 512 && e.bitLength <= 64) {
          return RsaModExp(n, e);
        }
      }
      for (final child in node.elements) {
        final r = _findRsaKey(child);
        if (r != null) return r;
      }
    } else if (node is ASN1BitString) {
      // SubjectPublicKeyInfo wraps the RSAPublicKey SEQUENCE in a BIT STRING.
      try {
        final inner = ASN1Parser(node.contentBytes()).nextObject();
        return _findRsaKey(inner);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

Uint8List _pemToDer(String pem) {
  final b64 = pem
      .replaceAll(RegExp(r'-----BEGIN [^-]+-----'), '')
      .replaceAll(RegExp(r'-----END [^-]+-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  return base64.decode(b64);
}

/// Reads our own client RSA public numbers from the private key PEM.
RsaModExp clientModExpFromPrivatePem(String privatePem) {
  final priv = CryptoUtils.rsaPrivateKeyFromPem(privatePem);
  final n = priv.modulus ?? priv.n!;
  final e = priv.publicExponent ?? priv.exponent ?? BigInt.from(65537);
  return RsaModExp(n, e);
}

/// Produces a random hex device id.
String randomHexId([int bytes = 6]) {
  final rnd = Random.secure();
  final sb = StringBuffer();
  for (var i = 0; i < bytes; i++) {
    sb.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
