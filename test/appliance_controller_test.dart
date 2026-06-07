import 'package:atv_remote/appliances/appliance.dart';
import 'package:atv_remote/appliances/appliance_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // The IR-emitter probe goes through a MethodChannel; stub it to "no IR".
    const channel = MethodChannel('com.molood.atv_remote/ir');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'hasIrEmitter') return false;
      return null;
    });
  });

  Appliance ac(String id, {String name = 'AC', String brand = 'gree'}) =>
      Appliance(
        id: id,
        name: name,
        kind: ApplianceKind.airConditioner,
        transport: ApplianceTransport.builtinIr,
        brand: brand,
      );

  test('save adds an appliance and persists it across a reload', () async {
    final c = ApplianceController();
    await c.load();
    expect(c.appliances, isEmpty);

    await c.save(ac('app_1', name: 'Living Room'));
    expect(c.appliances, hasLength(1));
    expect(c.appliances.first.name, 'Living Room');

    // A fresh controller reading the same prefs should see it.
    final c2 = ApplianceController();
    await c2.load();
    expect(c2.appliances, hasLength(1));
    expect(c2.appliances.first.id, 'app_1');
  });

  test('save upserts by id (no duplicates)', () async {
    final c = ApplianceController();
    await c.load();
    await c.save(ac('app_1', name: 'First'));
    await c.save(ac('app_1', name: 'Renamed'));
    expect(c.appliances, hasLength(1));
    expect(c.appliances.first.name, 'Renamed');
  });

  test('rename updates the name and ignores empty/unchanged', () async {
    final c = ApplianceController();
    await c.load();
    final a = ac('app_1', name: 'Old');
    await c.save(a);

    await c.rename(a, '   '); // whitespace -> ignored
    expect(c.appliances.first.name, 'Old');

    await c.rename(a, 'New');
    expect(c.appliances.first.name, 'New');
  });

  test('remove deletes the appliance', () async {
    final c = ApplianceController();
    await c.load();
    final a = ac('app_1');
    await c.save(a);
    expect(c.appliances, hasLength(1));

    await c.remove(a);
    expect(c.appliances, isEmpty);

    final c2 = ApplianceController();
    await c2.load();
    expect(c2.appliances, isEmpty);
  });

  test('a Wi-Fi appliance secret round-trips through secure storage', () async {
    final c = ApplianceController();
    await c.load();
    const wifi = Appliance(
      id: 'hub_1',
      name: 'Hub',
      kind: ApplianceKind.airConditioner,
      transport: ApplianceTransport.irHub,
      brand: 'gree',
      host: '192.168.1.9',
      secret: 'hub-token-123',
    );
    await c.save(wifi);

    // Reload: the metadata is in prefs, the secret in the keystore.
    final c2 = ApplianceController();
    await c2.load();
    expect(c2.appliances, hasLength(1));
    expect(c2.appliances.first.host, '192.168.1.9');
    expect(c2.appliances.first.secret, 'hub-token-123');
  });

  test('applyAc on built-in IR with no emitter reports failure', () async {
    final c = ApplianceController();
    await c.load();
    final a = ac('app_1');
    await c.save(a);
    // No IR emitter (stubbed false) -> the send can't succeed.
    final ok = await c.applyAc(a, const AcState(power: true, temp: 22));
    expect(ok, isFalse);
    // ...but the desired state is still persisted optimistically.
    expect(c.appliances.first.acState.temp, 22);
    expect(c.appliances.first.acState.power, isTrue);
  });
}
