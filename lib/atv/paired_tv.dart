import 'dart:convert';

import 'backend.dart';
import 'certificate.dart';

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
  });

  ClientCertificate get cert => ClientCertificate(keyPem, certPem);

  PairedTv copyWith({
    String? name,
    String? host,
    int? lastUsed,
    int? port,
    String? authToken,
  }) =>
      PairedTv(
        host: host ?? this.host,
        name: name ?? this.name,
        protocol: protocol,
        port: port ?? this.port,
        certPem: certPem,
        keyPem: keyPem,
        authToken: authToken ?? this.authToken,
        lastUsed: lastUsed ?? this.lastUsed,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'name': name,
        'protocol': protocol.name,
        'port': port,
        'cert': certPem,
        'key': keyPem,
        'authToken': authToken,
        'lastUsed': lastUsed,
      };

  factory PairedTv.fromJson(Map<String, dynamic> j) => PairedTv(
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
      jsonEncode(tvs.map((t) => t.toJson()).toList());

  static List<PairedTv> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PairedTv.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
