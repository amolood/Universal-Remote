import 'dart:typed_data';

import 'package:atv_remote/atv/messages.dart';
import 'package:atv_remote/proto/protobuf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('voice protobuf messages', () {
    test('voiceBegin (field 30) carries session_id', () {
      final fields = ProtoReader(RemoteMessages.voiceBegin(7)).readAll();
      final inner = ProtoReader(fields[30]!.bytes!).readAll();
      expect(inner[1]?.varint, 7);
    });

    test('voicePayload (field 31) carries session_id + samples', () {
      final samples = Uint8List.fromList([1, 2, 3, 4, 250, 0]);
      final fields =
          ProtoReader(RemoteMessages.voicePayload(3, samples)).readAll();
      final inner = ProtoReader(fields[31]!.bytes!).readAll();
      expect(inner[1]?.varint, 3); // session_id
      expect(inner[2]?.bytes, samples); // samples
    });

    test('voiceEnd (field 32) carries session_id', () {
      final fields = ProtoReader(RemoteMessages.voiceEnd(9)).readAll();
      final inner = ProtoReader(fields[32]!.bytes!).readAll();
      expect(inner[1]?.varint, 9);
    });

    test('activeFeatures advertises VOICE (bit 8)', () {
      expect(RemoteMessages.activeFeatures & 8, 8);
    });
  });
}
