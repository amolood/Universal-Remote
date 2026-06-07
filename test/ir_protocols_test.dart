import 'package:atv_remote/appliances/ir_protocols.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decodes a pulse-distance LSB-first word from a burst, given the timing
/// thresholds. Returns the decoded integer over [nbits] starting at burst
/// index [start] (after any leader). Used to verify NEC/Samsung framing.
int _decodeLsb(List<int> burst, int start, int nbits, int oneSpaceMin) {
  var word = 0;
  var idx = start;
  for (var i = 0; i < nbits; i++) {
    idx++; // skip mark
    final space = burst[idx];
    if (space >= oneSpaceMin) word |= 1 << i;
    idx++; // advance past space
  }
  return word;
}

void main() {
  group('NEC32', () {
    test('carrier is 38kHz', () => expect(NecProtocol.carrierHz, 38000));

    test('standard frame has leader, 32 bits, stop mark', () {
      final b = NecProtocol.standard(0x04, 0x08);
      expect(b[0], 9000);
      expect(b[1], 4500);
      // 2 leader + 64 bit entries + 1 stop = 67.
      expect(b.length, 67);
      expect(b.last, 560); // stop mark
    });

    test('standard frame inverts address and command bytes', () {
      final b = NecProtocol.standard(0x04, 0x08);
      final word = _decodeLsb(b, 2, 32, 1000);
      expect(word & 0xFF, 0x04); // address
      expect((word >> 8) & 0xFF, 0xFB); // ~address
      expect((word >> 16) & 0xFF, 0x08); // command
      expect((word >> 24) & 0xFF, 0xF7); // ~command
    });

    test('extended frame keeps a non-inverted 16-bit address', () {
      // Hisense-style: address 0x00FD not inverted, command + ~command.
      final b = NecProtocol.extended(0x00FD, 0xB0);
      final word = _decodeLsb(b, 2, 32, 1000);
      expect(word & 0xFFFF, 0x00FD);
      expect((word >> 16) & 0xFF, 0xB0);
      expect((word >> 24) & 0xFF, 0x4F); // ~0xB0
    });
  });

  group('Samsung32', () {
    test('symmetric 4480 leader', () {
      final b = SamsungProtocol.frame(0x07, 0x02);
      expect(b[0], 4480);
      expect(b[1], 4480);
      expect(b.length, 67);
    });

    test('duplicates the customer byte (NOT inverted) and inverts command', () {
      final b = SamsungProtocol.frame(0x07, 0x02);
      final word = _decodeLsb(b, 2, 32, 1000);
      expect(word & 0xFF, 0x07);
      expect((word >> 8) & 0xFF, 0x07); // duplicated, not 0xF8
      expect((word >> 16) & 0xFF, 0x02);
      expect((word >> 24) & 0xFF, 0xFD); // ~0x02
    });

    test('known Samsung power code 0xE0E040BF decodes correctly', () {
      // Samsung TV power: customer 0xE0, command 0x40 (=> ~cmd 0xBF).
      final b = SamsungProtocol.frame(0xE0, 0x40);
      final word = _decodeLsb(b, 2, 32, 1000);
      // Reconstruct the conventional big-endian display value E0 E0 40 BF.
      final display = ((word & 0xFF) << 24) |
          (((word >> 8) & 0xFF) << 16) |
          (((word >> 16) & 0xFF) << 8) |
          ((word >> 24) & 0xFF);
      expect(display, 0xE0E040BF);
    });
  });

  group('Sony SIRC', () {
    test('carrier is 40kHz, not 38', () => expect(SonyProtocol.carrierHz, 40000));

    test('repeats the frame 3 times by default', () {
      final one = SonyProtocol.frame(0x15, 0x01, repeats: 1);
      final three = SonyProtocol.frame(0x15, 0x01, repeats: 3);
      expect(three.length, one.length * 3);
    });

    test('12-bit frame starts with the 2400 start mark', () {
      final b = SonyProtocol.frame(0x15, 0x01, repeats: 1);
      expect(b[0], 2400);
      expect(b[1], 600);
      // start(2) + 12 bits * 2 entries = 26.
      expect(b.length, 26);
    });
  });

  group('Kaseikyo / Panasonic', () {
    test('carrier is 37kHz', () => expect(KaseikyoProtocol.carrierHz, 37000));

    test('frame has the 3456 leader and is 48 bits + stop', () {
      final b =
          KaseikyoProtocol.frame(KaseikyoProtocol.panasonicVendor, 0x80, 0, 0x3D);
      expect(b[0], 3456);
      expect(b[1], 1728);
      // 2 leader + 96 bit entries + 1 stop.
      expect(b.length, 99);
    });

    test('checksum byte is device ^ subdevice ^ command', () {
      const dev = 0x80, sub = 0x12, cmd = 0x3D;
      final b = KaseikyoProtocol.frame(0x2002, dev, sub, cmd);
      // Checksum is the last 8 bits before the stop mark (bits 40..47).
      final word = _decodeLsb(b, 2 + 80, 8, 800);
      expect(word, (dev ^ sub ^ cmd) & 0xFF);
    });
  });

  group('Sharp', () {
    test('no leader; starts directly with a 260 bit mark', () {
      final b = SharpProtocol.frame(0x01, 0x16);
      expect(b[0], 260);
    });

    test('sends two frames separated by a gap', () {
      final b = SharpProtocol.frame(0x01, 0x16);
      expect(b.contains(40000), isTrue); // inter-frame gap present
    });
  });

  group('RC5 (Manchester)', () {
    test('carrier is 36kHz', () => expect(Rc5Protocol.carrierHz, 36000));

    test('burst starts with a mark and all runs are positive multiples of 889',
        () {
      final b = Rc5Protocol.frame(0x00, 0x0C); // Philips power
      expect(b.isNotEmpty, isTrue);
      for (final d in b) {
        expect(d > 0, isTrue);
        expect(d % 889, 0); // every run is a whole number of half-bits
      }
    });
  });

  group('RC6 (Manchester)', () {
    test('carrier is 36kHz', () => expect(Rc6Protocol.carrierHz, 36000));

    test('starts with the 2666/889 leader', () {
      final b = Rc6Protocol.frame(0x00, 0x0C);
      expect(b[0], 2666);
      expect(b[1] >= 889, isTrue);
    });
  });
}
