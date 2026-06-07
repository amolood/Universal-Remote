// Drives a full voice session against a paired Google TV and logs every byte.
// Reuses the saved cert. Sends KEYCODE_SEARCH, waits for remote_voice_begin,
// echoes begin, streams synthetic PCM chunks, then voice_end.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:atv_remote/atv/framing.dart';
import 'package:atv_remote/atv/messages.dart';
import 'package:atv_remote/atv/key_codes.dart';

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : '192.168.1.10';
  final certPem = File('tool/.last_cert.pem').readAsStringSync();
  final keyPem = File('tool/.last_key.pem').readAsStringSync();
  final ctx = SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(certPem.codeUnits)
    ..usePrivateKeyBytes(keyPem.codeUnits);
  stdout.writeln('connecting $host:6466 ...');
  final sock = await SecureSocket.connect(host, 6466, context: ctx,
      onBadCertificate: (_) => true, timeout: const Duration(seconds: 8));
  final framer = MessageFramer();
  int? session;
  bool started = false;

  sock.listen((data) async {
    for (final p in framer.addBytes(data)) {
      final inc = RemoteIncoming.parse(p);
      final tag = _name(inc.field);
      stdout.writeln('<< field=${inc.field} ($tag) len=${p.length} ${inc.field==31?"":_hex(p)}');
      if (inc.field == 1) {
        sock.add(frame(RemoteMessages.configure()));
      } else if (inc.field == 2) {
        sock.add(frame(RemoteMessages.setActive(RemoteMessages.activeFeatures)));
      } else if (inc.field == 8) {
        sock.add(frame(RemoteMessages.pingResponse(inc.pingVal ?? 1)));
      } else if (inc.field == 40 && !started) {
        started = true;
        // Remote is active. Begin voice in 1s.
        Future.delayed(const Duration(seconds: 1), () {
          stdout.writeln('>> sending KEYCODE_SEARCH to start voice');
          sock.add(frame(RemoteMessages.keyInject(
              keyCode: 84, direction: KeyDirection.short)));
        });
      } else if (inc.field == 30) {
        session = inc.voiceSessionId ?? 0;
        stdout.writeln('   >>> GOT voice_begin session=$session — echoing begin + streaming PCM');
        sock.add(frame(RemoteMessages.voiceBegin(session!)));
        // stream ~1.5s of 8kHz mono 16-bit PCM tone in 20KB chunks
        final pcm = _tone(durationMs: 1500);
        const maxSize = 20 * 1024;
        for (var i = 0; i < pcm.length; i += maxSize) {
          final end = (i + maxSize < pcm.length) ? i + maxSize : pcm.length;
          sock.add(frame(RemoteMessages.voicePayload(session!, pcm.sublist(i, end))));
          await Future.delayed(const Duration(milliseconds: 80));
        }
        stdout.writeln('   >>> sent ${pcm.length} PCM bytes; ending voice');
        sock.add(frame(RemoteMessages.voiceEnd(session!)));
      }
    }
  }, onError: (e) => stdout.writeln('socket error: $e'),
     onDone: () => stdout.writeln('socket closed'));

  await Future.delayed(const Duration(seconds: 10));
  stdout.writeln('done');
  sock.destroy();
  exit(0);
}

// 8kHz mono 16-bit PCM sine tone.
Uint8List _tone({required int durationMs}) {
  const rate = 8000;
  final samples = (rate * durationMs) ~/ 1000;
  final b = BytesBuilder();
  for (var i = 0; i < samples; i++) {
    final v = (sin(2 * pi * 440 * i / rate) * 12000).round();
    b.addByte(v & 0xff);
    b.addByte((v >> 8) & 0xff);
  }
  return b.toBytes();
}

String _name(int f) => const {
  1: 'configure', 2: 'set_active', 3: 'error', 8: 'ping', 9: 'pong',
  20: 'ime_key_inject', 30: 'voice_begin', 31: 'voice_payload', 32: 'voice_end',
  40: 'remote_start', 50: 'set_volume', 90: 'app_link',
}[f] ?? '?';

String _hex(Uint8List b) => b.length > 40
    ? '${b.sublist(0, 40).map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ')} ...'
    : b.map((x)=>x.toRadixString(16).padLeft(2,'0')).join(' ');
