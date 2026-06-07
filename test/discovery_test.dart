import 'package:atv_remote/atv/discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SSDP device id extraction', () {
    test('extracts a canonical uuid and lowercases it', () {
      const response = 'HTTP/1.1 200 OK\r\n'
          'LOCATION: http://192.168.1.20:3000/\r\n'
          'USN: uuid:11AA22BB-33CC-44DD-55EE-66FF77AA88BB::urn:lge\r\n\r\n';
      expect(
        TvDiscovery.ssdpDeviceId(response),
        'uuid:11aa22bb-33cc-44dd-55ee-66ff77aa88bb',
      );
    });

    test('finds a uuid embedded elsewhere when USN lacks one', () {
      const response = 'HTTP/1.1 200 OK\r\n'
          'SERVER: Linux UPnP/1.0\r\n'
          'ST: uuid:abcdef12-3456-7890-abcd-ef1234567890\r\n\r\n';
      expect(
        TvDiscovery.ssdpDeviceId(response),
        'uuid:abcdef12-3456-7890-abcd-ef1234567890',
      );
    });

    test('returns null when no uuid is present', () {
      const response = 'HTTP/1.1 200 OK\r\n'
          'LOCATION: http://192.168.1.10:8060/\r\n'
          'ST: roku:ecp\r\n\r\n';
      expect(TvDiscovery.ssdpDeviceId(response), isNull);
    });
  });
}
