import 'dart:typed_data';

import 'package:atv_remote/atv/framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('framing', () {
    test('frame() prepends a varint length prefix', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final framed = frame(payload);
      expect(framed.first, 3); // length prefix for short payload
      expect(framed.sublist(1), payload);
    });

    test('round-trips a single message', () {
      final payload = Uint8List.fromList(List.generate(50, (i) => i));
      final out = MessageFramer().addBytes(frame(payload));
      expect(out.length, 1);
      expect(out.first, payload);
    });

    test('reassembles a message split across reads', () {
      final payload = Uint8List.fromList(List.generate(200, (i) => i % 256));
      final framed = frame(payload);
      final framer = MessageFramer();
      // Feed it one byte at a time.
      final results = <Uint8List>[];
      for (final b in framed) {
        results.addAll(framer.addBytes([b]));
      }
      expect(results.length, 1);
      expect(results.first, payload);
    });

    test('splits multiple messages in one buffer', () {
      final a = Uint8List.fromList([10, 20]);
      final b = Uint8List.fromList([30, 40, 50]);
      final buf = <int>[...frame(a), ...frame(b)];
      final out = MessageFramer().addBytes(buf);
      expect(out.length, 2);
      expect(out[0], a);
      expect(out[1], b);
    });

    test('handles a large (multi-byte varint length) payload', () {
      final payload = Uint8List.fromList(List.generate(5000, (i) => i % 256));
      final framed = frame(payload);
      // 5000 needs a 2-byte varint prefix.
      expect(framed.length, greaterThan(5001));
      final out = MessageFramer().addBytes(framed);
      expect(out.single.length, 5000);
    });
  });
}
