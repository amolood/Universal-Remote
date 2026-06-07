import 'package:atv_remote/atv/key_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keyCodeForChar', () {
    test('maps lowercase letters to KEYCODE_A..Z', () {
      expect(keyCodeForChar('a'), 29);
      expect(keyCodeForChar('z'), 54);
    });

    test('is case-insensitive', () {
      expect(keyCodeForChar('A'), keyCodeForChar('a'));
      expect(keyCodeForChar('Z'), keyCodeForChar('z'));
    });

    test('maps digits to KEYCODE_0..9', () {
      expect(keyCodeForChar('0'), 7);
      expect(keyCodeForChar('9'), 16);
    });

    test('maps supported punctuation', () {
      expect(keyCodeForChar(' '), 62);
      expect(keyCodeForChar('.'), 56);
      expect(keyCodeForChar(','), 55);
      expect(keyCodeForChar('@'), 77);
      expect(keyCodeForChar('-'), 69);
      expect(keyCodeForChar('/'), 76);
    });

    test('returns null for unsupported characters and empty input', () {
      expect(keyCodeForChar(''), isNull);
      expect(keyCodeForChar('#'), isNull);
      expect(keyCodeForChar('é'), isNull);
    });
  });

  group('KeyCode.digit', () {
    test('maps 0-9 to KEYCODE_0..9', () {
      expect(KeyCode.digit(0), 7);
      expect(KeyCode.digit(9), 16);
    });
  });
}
