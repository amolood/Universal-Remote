import 'dart:convert';

import 'backend.dart';
import 'certificate.dart';
import 'secret_store.dart';

/// A TV we have completed pairing with: its address, friendly name, protocol,
/// and (for Google TV) the client identity the TV recognises. Persisted as JSON.
class PairedTv {
  final String host;
  final String name;
  final RemoteProtocol protocol;
  final int port; // control port (CVTE websocket port; Google TV uses 6466)
  final String certPem; // empty for CVTE
  final String keyPem; // empty for CVTE

  /// Per-protocol auth credential: Samsung token / LG client-key. Empty when
  /// not yet authorized or not applicable.
  final String authToken;

  /// Stable device identity (SSDP UUID / mDNS name / Roku serial). Lets us
  /// recognise this TV after its IP changes. Empty for manually-entered TVs,
  /// which can only be matched by host.
  final String deviceId;

  /// Epoch millis of last successful connection — used to sort the list so the
  /// most recently used TV is offered first. Passed in (not generated) because
  /// the workflow/runtime forbids ad-hoc clocks; the controller stamps it.
  final int lastUsed;

  const PairedTv({
    required this.host,
    required this.name,
    required this.lastUsed,
    this.protocol = RemoteProtocol.googleTv,
    this.port = 6466,
    this.certPem = '',
    this.keyPem = '',
    this.authToken = '',
    this.deviceId = '',
  });

  ClientCertificate get cert => ClientCertificate(keyPem, certPem);

  /// Secure-storage key. Prefers the stable device id (survives IP changes);
  /// falls back to protocol+host for manually-entered TVs with no device id.
  String get id => deviceId.isNotEmpty
      ? '${protocol.name}_$deviceId'
      : '${protocol.name}_$host';

  PairedTv copyWith({
    String? name,
    String? host,
    int? lastUsed,
    int? port,
    String? authToken,
    String? deviceId,
  }) =>
      PairedTv(
        host: host ?? this.host,
        name: name ?? this.name,
        protocol: protocol,
        port: port ?? this.port,
        certPem: certPem,
        keyPem: keyPem,
        authToken: authToken ?? this.authToken,
        deviceId: deviceId ?? this.deviceId,
        lastUsed: lastUsed ?? this.lastUsed,
      );

  /// Returns a copy carrying the given secrets (read back from secure storage).
  PairedTv withSecrets(TvSecrets s) => PairedTv(
        host: host,
        name: name,
        protocol: protocol,
        port: port,
        certPem: s.certPem,
        keyPem: s.keyPem,
        authToken: s.authToken,
        deviceId: deviceId,
        lastUsed: lastUsed,
      );

  /// The secrets held by this record (to hand to the secure store).
  TvSecrets get secrets =>
      TvSecrets(certPem: certPem, keyPem: keyPem, authToken: authToken);

  /// Non-sensitive metadata only — this is what goes into SharedPreferences.
  /// The cert, key, and authToken live in [SecretStore] instead.
  Map<String, dynamic> toMetadataJson() => {
        'host': host,
        'name': name,
        'protocol': protocol.name,
        'port': port,
        'deviceId': deviceId,
        'lastUsed': lastUsed,
      };

  factory PairedTv.fromMetadataJson(Map<String, dynamic> j) => PairedTv(
        host: j['host'] as String,
        name: (j['name'] as String?) ?? 'TV',
        protocol: RemoteProtocol.values.firstWhere(
          (p) => p.name == j['protocol'],
          orElse: () => RemoteProtocol.googleTv,
        ),
        port: (j['port'] as int?) ?? 6466,
        deviceId: (j['deviceId'] as String?) ?? '',
        lastUsed: (j['lastUsed'] as int?) ?? 0,
      );

  /// Legacy decode: older builds stored cert/key/token inline in the JSON. We
  /// read those once on upgrade so they can be migrated into [SecretStore].
  factory PairedTv.fromLegacyJson(Map<String, dynamic> j) => PairedTv(
        host: j['host'] as String,
        name: (j['name'] as String?) ?? 'TV',
        protocol: RemoteProtocol.values.firstWhere(
          (p) => p.name == j['protocol'],
          orElse: () => RemoteProtocol.googleTv,
        ),
        port: (j['port'] as int?) ?? 6466,
        certPem: (j['cert'] as String?) ?? '',
        keyPem: (j['key'] as String?) ?? '',
        authToken: (j['authToken'] as String?) ?? '',
        lastUsed: (j['lastUsed'] as int?) ?? 0,
      );

  static String encodeList(List<PairedTv> tvs) =>
      jsonEncode(tvs.map((t) => t.toMetadataJson()).toList());

  /// Decodes the metadata list. [legacy] true means the JSON may still carry
  /// inline secrets (pre-secure-storage format) — used only during migration.
  static List<PairedTv> decodeList(String? raw, {bool legacy = false}) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => legacy
              ? PairedTv.fromLegacyJson(e as Map<String, dynamic>)
              : PairedTv.fromMetadataJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// True if the stored JSON still has inline secrets (needs migration).
  static bool listHasInlineSecrets(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final list = jsonDecode(raw) as List;
      return list.any((e) =>
          e is Map &&
          ((e['cert'] as String?)?.isNotEmpty == true ||
              (e['key'] as String?)?.isNotEmpty == true ||
              (e['authToken'] as String?)?.isNotEmpty == true));
    } catch (_) {
      return false;
    }
  }
}
