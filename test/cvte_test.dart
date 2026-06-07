import 'dart:typed_data';

import 'package:atv_remote/atv/cvte_backend.dart';
import 'package:atv_remote/proto/protobuf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CVTE key message encodes type=1 + action string', () {
    final bytes = CvteMessages.key(19); // DPAD_UP
    final fields = ProtoReader(bytes).readAll();
    expect(fields[1]?.varint, 1); // type = KEY_EVENT
    expect(decodeUtf8(fields[2]!.bytes!), '19'); // action = keycode
  });

  test('CVTE mouse-move encodes type=3 + Pointer{x,y} floats', () {
    final bytes = CvteMessages.mouseMove(12.5, -3.0);
    final fields = ProtoReader(bytes).readAll();
    expect(fields[1]?.varint, 3); // MOUSE_MOVE_EVENT
    // Pointer is a nested message in field 3.
    final pointer = ProtoReader(fields[3]!.bytes!).readAll();
    final x = _readFloat(pointer[1]!.rawFixed32!);
    final y = _readFloat(pointer[2]!.rawFixed32!);
    expect(x, closeTo(12.5, 0.001));
    expect(y, closeTo(-3.0, 0.001));
  });

  test('CVTE mouse-click encodes type=4', () {
    final fields = ProtoReader(CvteMessages.mouseClick()).readAll();
    expect(fields[1]?.varint, 4);
  });
}

double _readFloat(Uint8List le) =>
    ByteData.sublistView(le).getFloat32(0, Endian.little);
