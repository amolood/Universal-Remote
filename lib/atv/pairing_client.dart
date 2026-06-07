import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'certificate.dart';
import 'framing.dart';
import 'messages.dart';
import 'pairing_secret.dart';

/// Drives the Android TV pairing handshake on port 6467.
///
/// Flow:
///   1. TLS connect presenting our client certificate.
///   2. -> PairingRequest, <- PairingRequestAck
///   3. -> Options,         <- Options
///   4. -> Configuration,   <- ConfigurationAck   (TV now shows a 6-hex code)
///   5. user types code -> we send Secret, <- SecretAck  => paired.
class PairingClient {
  static const int port = 6467;

  final String host;
  final ClientCertificate cert;
  final String clientName;

  SecureSocket? _socket;
  final MessageFramer _framer = MessageFramer();
  final StreamController<PairingResponse> _responses =
      StreamController.broadcast();
  StreamSubscription? _sub;

  RsaModExp? _clientNumbers;
  RsaModExp? _serverNumbers;

  PairingClient({
    required this.host,
    required this.cert,
    this.clientName = 'Flutter ATV Remote',
  });

  /// Connects, presents the client cert, and runs the handshake up to the
  /// point where the TV displays the pairing code. Completes when the TV is
  /// ready to receive the secret.
  Future<void> start() async {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(_pemBytes(cert.certificatePem));
    ctx.usePrivateKeyBytes(_pemBytes(cert.privateKeyPem));

    _socket = await SecureSocket.connect(
      host,
      port,
      context: ctx,
      onBadCertificate: (_) => true, // TV uses a self-signed server cert
      timeout: const Duration(seconds: 10),
    );

    // Capture the TV's server certificate for the secret hash.
    final peer = _socket!.peerCertificate;
    if (peer == null) {
      throw const PairingException('No server certificate from TV');
    }
    _serverNumbers = RsaModExp.fromCertificateDer(
        Uint8List.fromList(peer.der));
    _clientNumbers = clientModExpFromPrivatePem(cert.privateKeyPem);

    _sub = _socket!.listen(
      _onData,
      onError: (e) => _responses.addError(e),
      onDone: () => _responses.close(),
    );

    // Step 2: PairingRequest
    _send(PairingMessages.pairingRequest(
      serviceName: 'atvremote',
      clientName: clientName,
    ));
    final ack = await _next();
    if (!ack.ok || !ack.hasRequestAck) {
      throw PairingException('PairingRequest rejected (status ${ack.status})');
    }

    // Step 3: Options
    _send(PairingMessages.optionsHex());
    final opts = await _next();
    if (!opts.ok) {
      throw PairingException('Options rejected (status ${opts.status})');
    }

    // Step 4: Configuration -> TV shows the code.
    _send(PairingMessages.configuration());
    final confAck = await _next();
    if (!confAck.ok || !confAck.hasConfigurationAck) {
      throw PairingException(
          'Configuration rejected (status ${confAck.status})');
    }
    // Now waiting for the user to read the code off the TV.
  }

  /// Sends the computed secret for the [code] the user typed off the TV.
  /// Returns true when the TV acknowledges (pairing succeeded).
  Future<bool> finish(String code) async {
    if (_clientNumbers == null || _serverNumbers == null) {
      throw const PairingException('Pairing not started');
    }
    final secret = PairingSecret.compute(
      client: _clientNumbers!,
      server: _serverNumbers!,
      code: code,
    );
    _send(PairingMessages.secret(secret));
    final ack = await _next();
    if (ack.status == PairingStatus.badSecret) {
      throw const PairingCodeError('TV rejected the code (bad secret)');
    }
    if (!ack.ok || !ack.hasSecretAck) {
      throw PairingException('Secret rejected (status ${ack.status})');
    }
    return true;
  }

  void dispose() {
    _sub?.cancel();
    _socket?.destroy();
    if (!_responses.isClosed) _responses.close();
  }

  // --- internals ---

  void _onData(Uint8List data) {
    for (final payload in _framer.addBytes(data)) {
      _responses.add(PairingResponse.parse(payload));
    }
  }

  void _send(Uint8List payload) => _socket!.add(frame(payload));

  Future<PairingResponse> _next() => _responses.stream.first.timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw const PairingException('Timed out waiting for the TV'),
      );

  static Uint8List _pemBytes(String pem) =>
      Uint8List.fromList(pem.codeUnits);
}

class PairingException implements Exception {
  final String message;
  const PairingException(this.message);
  @override
  String toString() => message;
}
