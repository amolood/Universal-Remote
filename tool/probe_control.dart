// Connects to an already-paired Google TV and logs every byte exchanged on
// the control channel, then sends HOME and watches the response.
import 'dart:io';
import 'dart:typed_data';
import 'package:atv_remote/atv/framing.dart';
import 'package:atv_remote/atv/messages.dart';
import 'package:atv_remote/atv/key_codes.dart';

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : '192.168.1.10';
  final certPem = File('tool/.last_cert.pem').existsSync()
      ? File('tool/.last_cert.pem').readAsStringSync() : null;
  final keyPem = File('tool/.last_key.pem').existsSync()
      ? File('tool/.last_key.pem').readAsStringSync() : null;
  if (certPem == null || keyPem == null) {
    stdout.writeln('No saved cert in tool/.last_cert.pem — pair first via live_pair.dart');
    exit(2);
  }
  final ctx = SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(certPem.codeUnits)
    ..usePrivateKeyBytes(keyPem.codeUnits);
  stdout.writeln('TLS connecting $host:6466 ...');
  final sock = await SecureSocket.connect(host, 6466, context: ctx,
      onBadCertificate: (_) => true, timeout: const Duration(seconds: 8));
  stdout.writeln('TLS connected. peer=${sock.peerCertificate?.subject}');
  final framer = MessageFramer();
  sock.listen((data) {
    for (final p in framer.addBytes(data)) {
      final inc = RemoteIncoming.parse(p);
      stdout.writeln('<< field=${inc.field} len=${p.length} hex=${_hex(p)}');
      if (inc.field == 1) {
        stdout.writeln('   -> got remote_configure; replying configure');
        sock.add(frame(RemoteMessages.configure()));
      } else if (inc.field == 2) {
        stdout.writeln('   -> got remote_set_active; echoing active features');
        sock.add(frame(RemoteMessages.setActive(RemoteMessages.activeFeatures)));
      } else if (inc.field == 8) {
        sock.add(frame(RemoteMessages.pingResponse(inc.pingVal ?? 1)));
      }
    }
  }, onError: (e) => stdout.writeln('socket error: $e'),
     onDone: () => stdout.writeln('socket closed'));
  await Future.delayed(const Duration(seconds: 2));
  stdout.writeln('>> sending HOME key');
  sock.add(frame(RemoteMessages.keyInject(keyCode: KeyCode.home, direction: KeyDirection.short)));
  await Future.delayed(const Duration(seconds: 3));
  stdout.writeln('done');
  sock.destroy();
  exit(0);
}
String _hex(Uint8List b) => b.map((x)=>x.toRadixString(16).padLeft(2,'0')).join(' ');
