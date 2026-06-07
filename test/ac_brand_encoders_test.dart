import 'package:atv_remote/appliances/ac_ir_encoder.dart';
import 'package:atv_remote/appliances/appliance.dart';
import 'package:flutter_test/flutter_test.dart';

/// Representative states to exercise every AC encoder across its field space.
const _states = [
  AcState(power: true, temp: 24, mode: AcMode.cool, fan: AcFan.auto),
  AcState(power: true, temp: 16, mode: AcMode.heat, fan: AcFan.high, swing: true),
  AcState(power: true, temp: 30, mode: AcMode.dry, fan: AcFan.low),
  AcState(power: true, temp: 22, mode: AcMode.fan, fan: AcFan.medium),
  AcState(power: true, temp: 28, mode: AcMode.auto, fan: AcFan.auto, swing: true),
  AcState(power: false, temp: 24, mode: AcMode.cool, fan: AcFan.auto),
];

/// The dedicated stateful encoders registered alongside Gree.
final _dedicated = AcIrProtocols.all
    .where((e) => e.brandId != 'gree')
    .toList();

void main() {
  test('all 14 dedicated AC encoders are registered', () {
    expect(_dedicated.length, 14);
    // No duplicate brand ids.
    final ids = _dedicated.map((e) => e.brandId).toList();
    expect(ids.toSet().length, ids.length);
  });

  group('every AC encoder produces valid frames', () {
    for (final enc in AcIrProtocols.all) {
      group(enc.brandId, () {
        test('carrier is a valid IR frequency', () {
          expect(enc.carrierHz, inInclusiveRange(36000, 40000));
        });

        test('encodes every representative state to a non-empty burst', () {
          for (final s in _states) {
            final burst = enc.encode(s);
            expect(burst, isNotEmpty, reason: '$s');
            // Every duration is a positive microsecond value.
            expect(burst.every((d) => d > 0), isTrue, reason: '$s');
            // Sane IR envelope: nothing longer than ~100ms (longest real gaps
            // are inter-section/leader pauses well under this).
            expect(burst.every((d) => d <= 100000), isTrue, reason: '$s');
            // First entry is a mark (burst starts with carrier on).
            expect(burst.first > 0, isTrue);
          }
        });

        test('distinct temperatures yield distinct frames (stateful)', () {
          // A stateful AC must encode temperature into the frame, so two
          // different temps (in the same mode) must differ. Skip the check for
          // encoders whose only difference would be a toggle (none here send a
          // constant frame regardless of state).
          final cool20 =
              enc.encode(const AcState(power: true, temp: 20, mode: AcMode.cool));
          final cool28 =
              enc.encode(const AcState(power: true, temp: 28, mode: AcMode.cool));
          expect(cool20, isNot(equals(cool28)),
              reason: '${enc.brandId} ignores temperature');
        });
      });
    }
  });
}
