import 'package:atv_remote/atv/backend.dart';
import 'package:atv_remote/atv/paired_tv.dart';
import 'package:atv_remote/atv/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PairedTv secure-storage id', () {
    test('prefers the stable device id when present', () {
      const tv = PairedTv(
        host: '192.168.1.5',
        name: 'Living Room',
        protocol: RemoteProtocol.lg,
        deviceId: 'uuid:abc-123',
        lastUsed: 0,
      );
      expect(tv.id, 'lg_uuid:abc-123');
    });

    test('falls back to protocol+host without a device id', () {
      const tv = PairedTv(
        host: '192.168.1.5',
        name: 'Manual TV',
        protocol: RemoteProtocol.samsung,
        lastUsed: 0,
      );
      expect(tv.id, 'samsung_192.168.1.5');
    });

    test('id is stable across a host change when device id is set', () {
      const a = PairedTv(
        host: '192.168.1.5',
        name: 'TV',
        protocol: RemoteProtocol.lg,
        deviceId: 'uuid:xyz',
        lastUsed: 0,
      );
      final b = a.copyWith(host: '192.168.1.99');
      expect(b.id, a.id); // re-bind to new IP keeps the same secret key
    });
  });

  group('PairedTv metadata serialization', () {
    test('metadata json omits secrets', () {
      const tv = PairedTv(
        host: '10.0.0.2',
        name: 'TV',
        protocol: RemoteProtocol.googleTv,
        certPem: 'CERT',
        keyPem: 'KEY',
        authToken: 'TOKEN',
        deviceId: 'mdns:tv._x._tcp',
        lastUsed: 42,
      );
      final json = tv.toMetadataJson();
      expect(json.containsKey('cert'), isFalse);
      expect(json.containsKey('key'), isFalse);
      expect(json.containsKey('authToken'), isFalse);
      expect(json['deviceId'], 'mdns:tv._x._tcp');
      expect(json['lastUsed'], 42);
    });

    test('round-trips metadata without secrets', () {
      const tv = PairedTv(
        host: '10.0.0.2',
        name: 'Bedroom',
        protocol: RemoteProtocol.roku,
        deviceId: 'roku:SERIAL1',
        port: 8060,
        lastUsed: 7,
      );
      final back = PairedTv.fromMetadataJson(tv.toMetadataJson());
      expect(back.host, tv.host);
      expect(back.name, tv.name);
      expect(back.protocol, tv.protocol);
      expect(back.deviceId, tv.deviceId);
      expect(back.port, tv.port);
      expect(back.certPem, isEmpty);
      expect(back.authToken, isEmpty);
    });

    test('withSecrets rehydrates credentials', () {
      const tv = PairedTv(
        host: '10.0.0.2',
        name: 'TV',
        protocol: RemoteProtocol.lg,
        deviceId: 'uuid:1',
        lastUsed: 0,
      );
      final full = tv.withSecrets(
          const TvSecrets(authToken: 'client-key', certPem: 'C', keyPem: 'K'));
      expect(full.authToken, 'client-key');
      expect(full.certPem, 'C');
      expect(full.keyPem, 'K');
      expect(full.id, tv.id); // id unchanged by rehydration
    });
  });

  group('Legacy migration detection', () {
    test('detects inline secrets in old-format json', () {
      const legacy =
          '[{"host":"1.2.3.4","protocol":"lg","authToken":"tok","lastUsed":0}]';
      expect(PairedTv.listHasInlineSecrets(legacy), isTrue);
    });

    test('new metadata-only json has no inline secrets', () {
      const modern =
          '[{"host":"1.2.3.4","protocol":"lg","deviceId":"uuid:1","lastUsed":0}]';
      expect(PairedTv.listHasInlineSecrets(modern), isFalse);
    });

    test('legacy decode preserves the inline credentials', () {
      const legacy =
          '[{"host":"1.2.3.4","protocol":"samsung","authToken":"T","lastUsed":0}]';
      final list = PairedTv.decodeList(legacy, legacy: true);
      expect(list, hasLength(1));
      expect(list.first.authToken, 'T');
    });

    test('handles malformed json without throwing', () {
      expect(PairedTv.listHasInlineSecrets('not json'), isFalse);
      expect(PairedTv.decodeList('not json'), isEmpty);
    });
  });
}
