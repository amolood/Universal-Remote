import 'dart:typed_data';

import 'package:atv_remote/proto/protobuf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtoReader varint', () {
    test('round-trips a 32-bit field through writer + reader', () {
      final bytes = (ProtoWriter()..writeInt(1, 0x7FFFFFFF)).toBytes();
      final f = ProtoReader(bytes).readField();
      expect(f.number, 1);
      expect(f.varint, 0x7FFFFFFF);
    });

    test('reads a full 10-byte (64-bit) varint without overflowing the loop',
        () {
      // 0xFFFFFFFFFFFFFFFF encoded as field 1, varint: ten 0xFF/0x01 bytes.
      // Reproduces a value whose high bits land past shift==64; the reader must
      // consume all bytes and not spin forever or throw.
      final data = Uint8List.fromList([
        0x08, // tag: field 1, wire type 0
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01,
      ]);
      final reader = ProtoReader(data);
      final f = reader.readField();
      expect(f.number, 1);
      // -1 is the two's-complement int64 for 0xFFFFFFFFFFFFFFFF.
      expect(f.varint, -1);
      expect(reader.hasMore, isFalse);
    });

    test('throws on an over-long (malformed) varint instead of looping', () {
      final data = Uint8List.fromList([
        0x08,
        ...List.filled(12, 0x80), // never-terminating continuation bytes
        0x01,
      ]);
      expect(() => ProtoReader(data).readField(), throwsFormatException);
    });
  });

  group('decodeUtf8', () {
    test('decodes valid multibyte UTF-8', () {
      expect(decodeUtf8(utf8Bytes('héllo €')), 'héllo €');
    });

    test('tolerates a truncated multibyte sequence (no RangeError)', () {
      // '€' is E2 82 AC; drop the last byte to simulate a buffer-boundary cut.
      final truncated = [0x68, 0x69, 0xE2, 0x82]; // "hi" + partial euro
      late String out;
      expect(() => out = decodeUtf8(truncated), returnsNormally);
      expect(out, startsWith('hi'));
      expect(out, contains('�')); // replacement char for the bad tail
    });
  });
}

/// Local UTF-8 encoder for the test (mirrors the encoder under test).
List<int> utf8Bytes(String s) {
  final out = <int>[];
  for (final r in s.runes) {
    if (r < 0x80) {
      out.add(r);
    } else if (r < 0x800) {
      out.add(0xC0 | (r >> 6));
      out.add(0x80 | (r & 0x3F));
    } else if (r < 0x10000) {
      out.add(0xE0 | (r >> 12));
      out.add(0x80 | ((r >> 6) & 0x3F));
      out.add(0x80 | (r & 0x3F));
    } else {
      out.add(0xF0 | (r >> 18));
      out.add(0x80 | ((r >> 12) & 0x3F));
      out.add(0x80 | ((r >> 6) & 0x3F));
      out.add(0x80 | (r & 0x3F));
    }
  }
  return out;
}
