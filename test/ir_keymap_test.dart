import 'package:atv_remote/atv/ir_backend.dart';
import 'package:atv_remote/atv/key_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IR NEC code mapping', () {
    test('maps common TV keys to NEC command bytes', () {
      expect(IrBackend.necCodeFor(KeyCode.power), 0x08);
      expect(IrBackend.necCodeFor(KeyCode.volumeUp), 0x02);
      expect(IrBackend.necCodeFor(KeyCode.volumeDown), 0x03);
      expect(IrBackend.necCodeFor(KeyCode.channelUp), 0x00);
      expect(IrBackend.necCodeFor(KeyCode.channelDown), 0x01);
      expect(IrBackend.necCodeFor(KeyCode.dpadCenter), 0x44);
      expect(IrBackend.necCodeFor(KeyCode.back), 0x45);
      expect(IrBackend.necCodeFor(KeyCode.home), 0x46);
    });

    test('mute and volumeMute share a code', () {
      expect(IrBackend.necCodeFor(KeyCode.mute), 0x09);
      expect(IrBackend.necCodeFor(KeyCode.volumeMute), 0x09);
    });

    test('returns null for keys with no IR mapping', () {
      expect(IrBackend.necCodeFor(KeyCode.digit(5)), isNull);
      expect(IrBackend.necCodeFor(99999), isNull);
    });
  });
}
