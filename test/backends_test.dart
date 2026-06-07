import 'package:atv_remote/atv/key_codes.dart';
import 'package:atv_remote/atv/roku_backend.dart';
import 'package:atv_remote/atv/samsung_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roku key mapping', () {
    test('maps navigation + media keys to Roku ECP names', () {
      expect(RokuBackend.rokuKeyFor(KeyCode.dpadUp), 'Up');
      expect(RokuBackend.rokuKeyFor(KeyCode.dpadCenter), 'Select');
      expect(RokuBackend.rokuKeyFor(KeyCode.home), 'Home');
      expect(RokuBackend.rokuKeyFor(KeyCode.back), 'Back');
      expect(RokuBackend.rokuKeyFor(KeyCode.volumeMute), 'VolumeMute');
      expect(RokuBackend.rokuKeyFor(KeyCode.mediaPlayPause), 'Play');
      expect(RokuBackend.rokuKeyFor(KeyCode.channelUp), 'ChannelUp');
    });

    test('maps digits to Lit_ literals', () {
      expect(RokuBackend.rokuKeyFor(KeyCode.digit(0)), 'Lit_0');
      expect(RokuBackend.rokuKeyFor(KeyCode.digit(7)), 'Lit_7');
    });

    test('returns null for unmapped keys', () {
      expect(RokuBackend.rokuKeyFor(99999), isNull);
    });
  });

  group('Samsung key mapping', () {
    test('maps to Tizen KEY_ names', () {
      expect(SamsungBackend.samsungKeyFor(KeyCode.dpadUp), 'KEY_UP');
      expect(SamsungBackend.samsungKeyFor(KeyCode.dpadCenter), 'KEY_ENTER');
      expect(SamsungBackend.samsungKeyFor(KeyCode.back), 'KEY_RETURN');
      expect(SamsungBackend.samsungKeyFor(KeyCode.volumeUp), 'KEY_VOLUP');
      expect(SamsungBackend.samsungKeyFor(KeyCode.mute), 'KEY_MUTE');
      expect(SamsungBackend.samsungKeyFor(KeyCode.power), 'KEY_POWER');
      expect(SamsungBackend.samsungKeyFor(KeyCode.channelDown), 'KEY_CHDOWN');
    });

    test('maps digits to KEY_0..KEY_9', () {
      expect(SamsungBackend.samsungKeyFor(KeyCode.digit(3)), 'KEY_3');
    });
  });
}
