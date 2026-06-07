import 'package:atv_remote/appliances/ac_ir_encoder.dart';
import 'package:atv_remote/appliances/appliance.dart';
import 'package:atv_remote/appliances/brand_catalog.dart';
import 'package:atv_remote/appliances/device_ir_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandCatalog integrity', () {
    test('brand ids are unique', () {
      final ids = BrandCatalog.all.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every brand covers at least one kind', () {
      for (final b in BrandCatalog.all) {
        expect(b.support, isNotEmpty, reason: b.id);
      }
    });

    test('the listed real-world brands are all present', () {
      const expected = [
        'lg', 'samsung', 'bosch', 'siemens', 'whirlpool', 'ge', 'electrolux',
        'frigidaire', 'panasonic', 'sharp', 'hitachi', 'toshiba', 'haier',
        'midea', 'hisense', 'beko', 'arcelik', 'candy', 'hoover', 'indesit',
        'hotpoint', 'zanussi', 'aeg', 'miele', 'liebherr', 'fisherpaykel',
        'kitchenaid', 'maytag', 'amana', 'kenmore', 'daewoo', 'gorenje',
        'smeg', 'subzero', 'wolf', 'viking', 'thermador', 'jennair', 'tcl',
        'xiaomi', 'philips',
      ];
      for (final id in expected) {
        expect(BrandCatalog.byId(id), isNotNull, reason: id);
      }
    });
  });

  group('IR encoder resolution', () {
    test('every IR-capable (brand, kind) resolves to a real encoder', () {
      for (final b in BrandCatalog.all) {
        b.support.forEach((kind, sup) {
          if (!sup.supportsIr) return;
          final id = BrandCatalog.irEncoderId(b.id, kind);
          expect(id, isNotNull, reason: '${b.id}/$kind');
          final resolved = AcIrProtocols.byId(id!) != null ||
              DeviceIrProtocols.byId(id) != null;
          expect(resolved, isTrue, reason: '${b.id}/$kind -> $id');
        });
      }
    });

    test('Wi-Fi-only brands are not IR-capable for their kinds', () {
      // Luxury kitchen brands have no IR remote.
      for (final id in ['miele', 'subzero', 'wolf', 'liebherr']) {
        final b = BrandCatalog.byId(id)!;
        for (final kind in b.support.keys) {
          expect(BrandCatalog.irCapable(id, kind), isFalse,
              reason: '$id/$kind');
        }
      }
    });

    test('AC brands resolve to the Gree generic AC encoder', () {
      // Samsung/LG/Midea etc. all map their AC line to the generic AC encoder.
      for (final id in ['lg', 'samsung', 'midea', 'gree']) {
        expect(BrandCatalog.irCapable(id, ApplianceKind.airConditioner), isTrue,
            reason: id);
        expect(BrandCatalog.irEncoderId(id, ApplianceKind.airConditioner),
            'gree',
            reason: id);
      }
    });

    test('TV brands resolve to a registered TV encoder', () {
      for (final id in ['lg', 'samsung', 'tcl', 'hisense']) {
        final encId = BrandCatalog.irEncoderId(id, ApplianceKind.tv);
        expect(DeviceIrProtocols.byId(encId!), isNotNull, reason: id);
      }
    });
  });

  group('Per-kind brand lists', () {
    test('every IR remote kind has at least one brand', () {
      for (final kind in [
        ApplianceKind.tv,
        ApplianceKind.airConditioner,
        ApplianceKind.fan,
        ApplianceKind.dvd,
        ApplianceKind.soundbar,
        ApplianceKind.radio,
        ApplianceKind.setTopBox,
        ApplianceKind.projector,
        ApplianceKind.heater,
      ]) {
        expect(BrandCatalog.forKind(kind), isNotEmpty, reason: kind.name);
      }
    });

    test('forKind is sorted premium before value', () {
      final tvs = BrandCatalog.forKind(ApplianceKind.tv);
      for (var i = 1; i < tvs.length; i++) {
        expect(tvs[i - 1].tier.index, lessThanOrEqualTo(tvs[i].tier.index));
      }
    });

    test('TV list includes major TV makers but not fridge-only brands', () {
      final tvIds = BrandCatalog.forKind(ApplianceKind.tv).map((b) => b.id);
      expect(tvIds, containsAll(['lg', 'samsung', 'tcl', 'hisense']));
      expect(tvIds, isNot(contains('miele')));
      expect(tvIds, isNot(contains('subzero')));
    });
  });

  group('Legacy fallback', () {
    test('an unknown brand id falls back to the generic encoder for the kind',
        () {
      // Appliances saved before the catalog stored the encoder id directly.
      expect(BrandCatalog.irEncoderId('gree', ApplianceKind.airConditioner),
          'gree');
      expect(
          BrandCatalog.irEncoderId('nec_tv', ApplianceKind.tv), 'nec_tv');
    });
  });
}
