import 'package:atv_remote/atv/cvte_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CvtePin.decode', () {
    test('returns null for empty / whitespace', () {
      expect(CvtePin.decode(''), isNull);
      expect(CvtePin.decode('   '), isNull);
    });

    test('does not throw on arbitrary input', () {
      for (final s in ['ABC', 'ZZZZZZ', '123', 'WXWXWX', '!!!', 'abcdef']) {
        // Should either decode to (host, port) or return null — never throw.
        expect(() => CvtePin.decode(s), returnsNormally);
      }
    });

    test('decoded host (when non-null) is a private IPv4', () {
      // Sweep a range of plausible codes; any that decode must yield a
      // 10.x / 172.x / 192.168.x address with a valid port.
      const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUV';
      for (var i = 0; i < 32; i++) {
        final code = '${alphabet[i]}23456';
        final r = CvtePin.decode(code);
        if (r != null) {
          final (host, port) = r;
          expect(
            host.startsWith('10.') ||
                host.startsWith('172.') ||
                host.startsWith('192.168.'),
            isTrue,
            reason: 'host=$host',
          );
          expect(port, inInclusiveRange(8125, 8128));
          for (final octet in host.split('.')) {
            expect(int.parse(octet), inInclusiveRange(0, 255));
          }
        }
      }
    });
  });
}
