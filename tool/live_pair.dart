// Standalone live test of the pairing + control flow against a real TV.
// Run:  dart run tool/live_pair.dart <host> [savedCertDir]
//
// Step 1 connects and triggers the TV to show a 6-char code, then prompts
// for it on stdin and finishes pairing. On success it opens the control
// connection and sends a HOME keypress so you can confirm control works.

import 'dart:io';

import 'package:atv_remote/atv/certificate.dart';
import 'package:atv_remote/atv/pairing_client.dart';
import 'package:atv_remote/atv/remote_client.dart';
import 'package:atv_remote/atv/key_codes.dart';

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : '192.168.1.10';
  stdout.writeln('Generating client certificate (RSA 2048)...');
  final cert = ClientCertificate.generate();

  stdout.writeln('Connecting to $host:6467 for pairing...');
  final pairing = PairingClient(host: host, cert: cert);
  await pairing.start();
  stdout.writeln('>> Look at the TV. It should now show a 6-character code.');
  stdout.writeln('>> Waiting for the code in /tmp/atv_pin (poll)...');

  // Poll a file for the code so an external driver can supply it without a TTY.
  final pinFile = File('/tmp/atv_pin');
  if (pinFile.existsSync()) pinFile.deleteSync();
  String code = '';
  for (var i = 0; i < 120; i++) {
    if (pinFile.existsSync()) {
      code = pinFile.readAsStringSync().trim();
      if (code.isNotEmpty) break;
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
  if (code.isEmpty) {
    stdout.writeln('No code provided in time. Aborting.');
    exit(2);
  }
  stdout.writeln('Got code: $code');

  await pairing.finish(code);
  stdout.writeln('PAIRED successfully!');

  // Save identity so the app / re-runs can reuse it.
  File('tool/.last_cert.pem').writeAsStringSync(cert.certificatePem);
  File('tool/.last_key.pem').writeAsStringSync(cert.privateKeyPem);
  stdout.writeln('Saved cert/key to tool/.last_cert.pem and tool/.last_key.pem');

  stdout.writeln('Connecting to $host:6466 for control...');
  final ctx = SecurityContext(withTrustedRoots: false);
  ctx.useCertificateChainBytes(cert.certificatePem.codeUnits);
  ctx.usePrivateKeyBytes(cert.privateKeyPem.codeUnits);
  final remote = RemoteClient(host: host, context: ctx);
  remote.stateStream.listen((s) => stdout.writeln('control state: $s'));
  await remote.connect();

  await Future.delayed(const Duration(seconds: 1));
  stdout.writeln('Sending HOME...');
  remote.sendKey(KeyCode.home);
  await Future.delayed(const Duration(seconds: 1));
  stdout.writeln('Sending VOLUME_UP...');
  remote.sendKey(KeyCode.volumeUp);
  await Future.delayed(const Duration(seconds: 2));

  stdout.writeln('Done. Disconnecting.');
  remote.dispose();
  exit(0);
}
