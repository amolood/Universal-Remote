import 'package:atv_remote/appliances/appliance.dart';
import 'package:atv_remote/appliances/device_ir_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FanState', () {
    test('clamps speed into range', () {
      expect(const FanState().copyWith(speed: 0).speed, FanState.minSpeed);
      expect(const FanState().copyWith(speed: 99).speed, FanState.maxSpeed);
      expect(const FanState().copyWith(speed: 2).speed, 2);
    });

    test('round-trips through json', () {
      const s = FanState(power: true, speed: 3, oscillate: true);
      final back = FanState.fromJson(s.toJson());
      expect(back.power, true);
      expect(back.speed, 3);
      expect(back.oscillate, true);
    });
  });

  group('LightState', () {
    test('clamps brightness 0..100', () {
      expect(const LightState().copyWith(brightness: -5).brightness, 0);
      expect(const LightState().copyWith(brightness: 250).brightness, 100);
    });

    test('round-trips through json', () {
      const s = LightState(power: true, brightness: 60);
      final back = LightState.fromJson(s.toJson());
      expect(back.power, true);
      expect(back.brightness, 60);
    });
  });

  group('Appliance.isOn across kinds', () {
    test('reflects the matching kind state', () {
      const fanOn = Appliance(
        id: 'f',
        name: 'Fan',
        kind: ApplianceKind.fan,
        transport: ApplianceTransport.builtinIr,
        fanState: FanState(power: true),
      );
      const lightOff = Appliance(
        id: 'l',
        name: 'Light',
        kind: ApplianceKind.light,
        transport: ApplianceTransport.builtinIr,
        lightState: LightState(power: false),
      );
      expect(fanOn.isOn, isTrue);
      expect(lightOff.isOn, isFalse);
    });

    test('non-AC state survives metadata round-trip', () {
      const a = Appliance(
        id: 'f',
        name: 'Fan',
        kind: ApplianceKind.fan,
        transport: ApplianceTransport.builtinIr,
        brand: 'nec_fan',
        fanState: FanState(power: true, speed: 2, oscillate: true),
      );
      final back = Appliance.fromMetadataJson(a.toMetadataJson());
      expect(back.kind, ApplianceKind.fan);
      expect(back.fanState.speed, 2);
      expect(back.fanState.oscillate, isTrue);
    });
  });

  group('HeaterState', () {
    test('clamps level into range', () {
      expect(const HeaterState().copyWith(level: 0).level, HeaterState.minLevel);
      expect(const HeaterState().copyWith(level: 9).level, HeaterState.maxLevel);
    });

    test('round-trips through json', () {
      const s = HeaterState(power: true, level: 3, oscillate: true);
      final back = HeaterState.fromJson(s.toJson());
      expect(back.power, true);
      expect(back.level, 3);
      expect(back.oscillate, true);
    });
  });

  group('ApplianceKind classification', () {
    test('state-based kinds are not key-based', () {
      for (final k in [
        ApplianceKind.airConditioner,
        ApplianceKind.fan,
        ApplianceKind.light,
        ApplianceKind.heater,
      ]) {
        expect(k.isKeyBased, isFalse, reason: k.name);
      }
    });

    test('remote-style kinds are key-based', () {
      for (final k in [
        ApplianceKind.tv,
        ApplianceKind.radio,
        ApplianceKind.dvd,
        ApplianceKind.setTopBox,
        ApplianceKind.projector,
        ApplianceKind.soundbar,
        ApplianceKind.generic,
      ]) {
        expect(k.isKeyBased, isTrue, reason: k.name);
      }
    });
  });

  group('DeviceKey.digit', () {
    test('maps 0..9 to the matching enum value', () {
      expect(DeviceKeyInfo.digit(0), DeviceKey.digit0);
      expect(DeviceKeyInfo.digit(5), DeviceKey.digit5);
      expect(DeviceKeyInfo.digit(9), DeviceKey.digit9);
    });
  });

  group('Device NEC IR encoders', () {
    test('every built-in encoder uses a 38kHz carrier', () {
      for (final e in DeviceIrProtocols.all) {
        expect(e.carrierHz, 38000, reason: e.brandId);
      }
    });

    test('there is at least one encoder per key-based & state IR kind', () {
      for (final k in [
        ApplianceKind.tv,
        ApplianceKind.fan,
        ApplianceKind.light,
        ApplianceKind.radio,
        ApplianceKind.dvd,
        ApplianceKind.setTopBox,
        ApplianceKind.projector,
        ApplianceKind.soundbar,
        ApplianceKind.heater,
      ]) {
        expect(DeviceIrProtocols.forKind(k), isNotEmpty, reason: k.name);
      }
    });

    test('media + numeric remotes encode all ten digits distinctly', () {
      for (final id in ['nec_dvd', 'nec_stb']) {
        final enc = DeviceIrProtocols.byId(id)!;
        final frames = <List<int>>[];
        for (var n = 0; n < 10; n++) {
          final f = enc.encode(DeviceKeyInfo.digit(n));
          expect(f, isNotNull, reason: '$id digit $n');
          frames.add(f!);
        }
        // All ten digit frames are unique.
        for (var i = 0; i < frames.length; i++) {
          for (var j = i + 1; j < frames.length; j++) {
            expect(frames[i], isNot(equals(frames[j])));
          }
        }
      }
    });

    test('DVD encodes media transport keys', () {
      final dvd = DeviceIrProtocols.byId('nec_dvd')!;
      expect(dvd.encode(DeviceKey.playPause), isNotNull);
      expect(dvd.encode(DeviceKey.stop), isNotNull);
      expect(dvd.encode(DeviceKey.eject), isNotNull);
      expect(dvd.encode(DeviceKey.fastForward), isNotNull);
    });

    test('TV power emits a valid NEC frame (leader + 32 bits + stop)', () {
      final tv = DeviceIrProtocols.byId('nec_tv')!;
      final p = tv.encode(DeviceKey.power)!;
      expect(p[0], 9000); // leader mark
      expect(p[1], 4500); // leader space
      // 2 leader + 64 bit halves + 1 stop = 67 entries.
      expect(p.length, 67);
      expect(p.every((v) => v > 0), isTrue);
    });

    test('different keys produce different patterns', () {
      final tv = DeviceIrProtocols.byId('nec_tv')!;
      expect(tv.encode(DeviceKey.volumeUp),
          isNot(equals(tv.encode(DeviceKey.volumeDown))));
    });

    test('returns null for keys the device has no code for', () {
      final fan = DeviceIrProtocols.byId('nec_fan')!;
      // A fan has no channel key.
      expect(fan.encode(DeviceKey.channelUp), isNull);
      expect(fan.encode(DeviceKey.power), isNotNull);
    });

    test('byId resolves known ids and rejects unknown', () {
      expect(DeviceIrProtocols.byId('nec_tv'), isNotNull);
      expect(DeviceIrProtocols.byId('nope'), isNull);
    });
  });
}
