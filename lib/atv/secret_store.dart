import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'log.dart';

/// Secure, OS-backed storage for the sensitive per-TV credentials: the Google TV
/// client certificate and private key, and the Samsung token / LG client-key.
///
/// These never go into SharedPreferences (which is plaintext on Android). Instead
/// they live in the Android Keystore / iOS Keychain via flutter_secure_storage,
/// keyed by the TV's stable id. Only non-sensitive metadata (host, name, protocol,
/// port, lastUsed) is persisted in SharedPreferences.
class SecretStore {
  SecretStore({FlutterSecureStorage? storage})
      : _s = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _s;

  /// One stable key per TV: protocol + host uniquely identify a pairing.
  static String idFor(String protocol, String host) => '${protocol}_$host';

  String _certKey(String id) => 'cert_$id';
  String _keyKey(String id) => 'key_$id';
  String _tokenKey(String id) => 'token_$id';

  /// Reads the secret bundle for a TV. Missing values come back as empty strings.
  Future<TvSecrets> read(String id) async {
    try {
      final cert = await _s.read(key: _certKey(id));
      final key = await _s.read(key: _keyKey(id));
      final token = await _s.read(key: _tokenKey(id));
      return TvSecrets(
        certPem: cert ?? '',
        keyPem: key ?? '',
        authToken: token ?? '',
      );
    } catch (e) {
      atvLog('secret read $id', e);
      return const TvSecrets();
    }
  }

  /// Writes the secret bundle for a TV. Empty values are removed rather than
  /// stored, so a protocol that has no token doesn't leave a stale entry.
  Future<void> write(String id, TvSecrets secrets) async {
    try {
      await _put(_certKey(id), secrets.certPem);
      await _put(_keyKey(id), secrets.keyPem);
      await _put(_tokenKey(id), secrets.authToken);
    } catch (e) {
      atvLog('secret write $id', e);
    }
  }

  Future<void> _put(String key, String value) async {
    if (value.isEmpty) {
      await _s.delete(key: key);
    } else {
      await _s.write(key: key, value: value);
    }
  }

  /// Erases all secrets for a TV (used when the user forgets it).
  Future<void> delete(String id) async {
    try {
      await _s.delete(key: _certKey(id));
      await _s.delete(key: _keyKey(id));
      await _s.delete(key: _tokenKey(id));
    } catch (e) {
      atvLog('secret delete $id', e);
    }
  }

  // ---- Generic single-value secrets (used by appliances: a hub token / key) ----

  Future<String?> readRaw(String key) async {
    try {
      return await _s.read(key: key);
    } catch (e) {
      atvLog('secret readRaw $key', e);
      return null;
    }
  }

  Future<void> writeRaw(String key, String value) async {
    try {
      await _put(key, value);
    } catch (e) {
      atvLog('secret writeRaw $key', e);
    }
  }

  Future<void> deleteRaw(String key) async {
    try {
      await _s.delete(key: key);
    } catch (e) {
      atvLog('secret deleteRaw $key', e);
    }
  }
}

/// The sensitive credentials for one TV.
class TvSecrets {
  final String certPem;
  final String keyPem;
  final String authToken;
  const TvSecrets({
    this.certPem = '',
    this.keyPem = '',
    this.authToken = '',
  });

  bool get isEmpty =>
      certPem.isEmpty && keyPem.isEmpty && authToken.isEmpty;
}
