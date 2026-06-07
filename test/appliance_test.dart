import 'package:atv_remote/appliances/ac_ir_encoder.dart';
import 'package:atv_remote/appliances/appliance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AcState', () {
    test('clamps temperature into range', () {
      expect(const AcState().copyWith(temp: 5).temp, AcState.minTemp);
      expect(const AcState().copyWith(temp: 99).temp, AcState.maxTemp);
      expect(const AcState().copyWith(temp: 22).temp, 22);
    });

    test('round-trips through json', () {
      const s = AcState(
          power: true, temp: 21, mode: AcMode.heat, fan: AcFan.high, swing: true);
      final back = AcState.fromJson(s.toJson());
      expect(back.power, true);
      expect(back.temp, 21);
      expect(back.mode, AcMode.heat);
      expect(back.fan, AcFan.high);
      expect(back.swing, true);
    });
  });

  group('Appliance serialization', () {
    test('metadata json omits the secret', () {
      const a = Appliance(
        id: 'app_1',
        name: 'Bedroom AC',
        kind: ApplianceKind.airConditioner,
        transport: ApplianceTransport.irHub,
        brand: 'gree',
        host: '192.168.1.50',
        secret: 'super-secret-token',
        lastUsed: 7,
      );
      final json = a.toMetadataJson();
      expect(json.containsKey('secret'), isFalse);
      expect(json['host'], '192.168.1.50');
      final back = Appliance.fromMetadataJson(json);
      expect(back.id, 'app_1');
      expect(back.brand, 'gree');
      expect(back.transport, ApplianceTransport.irHub);
      expect(back.secret, isEmpty); // secret never in metadata
    });

    test('needsSecret only for non-builtin transports', () {
      const builtin = Appliance(
          id: 'a',
          name: 'n',
          kind: ApplianceKind.airConditioner,
          transport: ApplianceTransport.builtinIr);
      const hub = Appliance(
          id: 'b',
          name: 'n',
          kind: ApplianceKind.airConditioner,
          transport: ApplianceTransport.irHub);
      expect(builtin.needsSecret, isFalse);
      expect(hub.needsSecret, isTrue);
    });

    test('decodeList tolerates malformed json', () {
      expect(Appliance.decodeList('not json'), isEmpty);
      expect(Appliance.decodeList(null), isEmpty);
    });
  });

  group('Gree AC IR encoder', () {
    final enc = GreeAcEncoder();

    test('uses a 38kHz carrier', () {
      expect(enc.carrierHz, 38000);
    });

    test('emits a non-empty pattern that starts with the leader', () {
      final p = enc.encode(const AcState(power: true, temp: 24));
      expect(p.length, greaterThan(60));
      expect(p[0], 9000); // leader mark
      expect(p[1], 4500); // leader space
    });

    test('pattern alternates plausible mark/space durations', () {
      final p = enc.encode(const AcState(power: true));
      // Every value is a positive microsecond duration.
      expect(p.every((v) => v > 0), isTrue);
      // All durations stay within a sane IR envelope (the inter-block gap is
      // the largest at 19ms).
      expect(p.every((v) => v <= 19000), isTrue);
    });

    test('different states produce different patterns', () {
      final cool = enc.encode(const AcState(power: true, temp: 20));
      final warm = enc.encode(const AcState(power: true, temp: 28));
      expect(cool, isNot(equals(warm)));

      final off = enc.encode(const AcState(power: false, temp: 24));
      final on = enc.encode(const AcState(power: true, temp: 24));
      expect(off, isNot(equals(on)));
    });

    test('is registered and resolvable by id', () {
      expect(AcIrProtocols.byId('gree'), isNotNull);
      expect(AcIrProtocols.byId('nope'), isNull);
    });
  });
}
