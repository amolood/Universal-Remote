import 'package:atv_remote/atv/key_codes.dart';
import 'package:atv_remote/atv/lg_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LG command mapping', () {
    test('navigation keys map to pointer-socket buttons', () {
      final up = LgBackend.lgCommandFor(KeyCode.dpadUp)!;
      expect(up.isButton, isTrue);
      expect(up.value, 'UP');

      expect(LgBackend.lgCommandFor(KeyCode.dpadDown)!.value, 'DOWN');
      expect(LgBackend.lgCommandFor(KeyCode.dpadLeft)!.value, 'LEFT');
      expect(LgBackend.lgCommandFor(KeyCode.dpadRight)!.value, 'RIGHT');
      expect(LgBackend.lgCommandFor(KeyCode.dpadCenter)!.value, 'ENTER');
      expect(LgBackend.lgCommandFor(KeyCode.back)!.value, 'BACK');
      expect(LgBackend.lgCommandFor(KeyCode.home)!.value, 'HOME');
      expect(LgBackend.lgCommandFor(KeyCode.menu)!.value, 'MENU');
    });

    test('audio/system keys map to SSAP requests', () {
      final volUp = LgBackend.lgCommandFor(KeyCode.volumeUp)!;
      expect(volUp.isButton, isFalse);
      expect(volUp.value, 'ssap://audio/volumeUp');

      expect(LgBackend.lgCommandFor(KeyCode.volumeDown)!.value,
          'ssap://audio/volumeDown');
      expect(LgBackend.lgCommandFor(KeyCode.channelUp)!.value,
          'ssap://tv/channelUp');
      expect(LgBackend.lgCommandFor(KeyCode.power)!.value,
          'ssap://system/turnOff');
    });

    test('mute carries a payload', () {
      final mute = LgBackend.lgCommandFor(KeyCode.mute)!;
      expect(mute.isButton, isFalse);
      expect(mute.value, 'ssap://audio/setMute');
      expect(mute.payload, {'mute': true});
    });

    test('digits map to numeric buttons', () {
      expect(LgBackend.lgCommandFor(KeyCode.digit(0))!.value, '0');
      expect(LgBackend.lgCommandFor(KeyCode.digit(9))!.value, '9');
      expect(LgBackend.lgCommandFor(KeyCode.digit(0))!.isButton, isTrue);
    });

    test('returns null for unmapped keys', () {
      expect(LgBackend.lgCommandFor(99999), isNull);
    });
  });
}
