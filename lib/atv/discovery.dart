import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import 'backend.dart';

/// A TV found on the local network via mDNS / DNS-SD.
class DiscoveredTv {
  final String name; // instance / advertised name
  final String host; // resolved IPv4 address
  final int port; // control port for the protocol
  final RemoteProtocol protocol;

  /// Stable identity that survives an IP change: the SSDP USN/UUID, the mDNS
  /// service instance name, or a device serial. Empty when the responder
  /// advertised nothing stable — then we fall back to matching on host.
  final String deviceId;

  DiscoveredTv({
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    this.deviceId = '',
  });

  @override
  bool operator ==(Object other) =>
      other is DiscoveredTv && other.host == host && other.protocol == protocol;

  @override
  int get hashCode => Object.hash(host, protocol);
}

/// Discovers TVs of both supported families on the local network:
///   - Google / Android TV  -> `_androidtvremote2._tcp`
///   - CVTE / Bytello boards -> `_share._tcp`
class TvDiscovery {
  static const String googleService = '_androidtvremote2._tcp.local';
  static const String cvteService = '_share._tcp.local';

  /// Single sweep over all supported discovery mechanisms; returns unique TVs.
  static Future<List<DiscoveredTv>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final results = await Future.wait([
      _discoverType(googleService, RemoteProtocol.googleTv, timeout),
      _discoverType(cvteService, RemoteProtocol.cvte, timeout),
      _discoverSsdp(timeout),
    ]);
    // Merge, de-duplicating by (host, protocol).
    final merged = <String, DiscoveredTv>{};
    for (final list in results) {
      for (final tv in list) {
        merged['${tv.protocol}:${tv.host}'] = tv;
      }
    }
    return merged.values.toList();
  }

  /// Discovers Roku, Samsung, and LG devices via SSDP (UDP multicast
  /// 239.255.255.250:1900). We send an M-SEARCH for each device family's
  /// search target and classify each responder by the ST/USN/SERVER headers.
  static Future<List<DiscoveredTv>> _discoverSsdp(Duration timeout) async {
    final found = <String, DiscoveredTv>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final target = InternetAddress('239.255.255.250');

      String search(String st) => 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'ST: $st\r\n'
          'MX: 2\r\n\r\n';

      for (final st in const [
        'roku:ecp',
        'urn:samsung.com:device:RemoteControlReceiver:1',
        'urn:lge-com:service:webos-second-screen:1',
        'urn:dial-multiscreen-org:service:dial:1',
        'ssdp:all',
      ]) {
        socket.send(search(st).codeUnits, target, 1900);
      }

      // host -> (protocol, stable device id). First classification wins.
      final classified = <String, RemoteProtocol>{};
      final ids = <String, String>{};
      final completer = Completer<void>();
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;
        final text = String.fromCharCodes(dg.data);
        final loc =
            RegExp(r'LOCATION:\s*http://([0-9.]+)', caseSensitive: false)
                .firstMatch(text);
        if (loc == null) return;
        final host = loc.group(1)!;
        final lower = text.toLowerCase();
        RemoteProtocol? proto;
        if (lower.contains('roku')) {
          proto = RemoteProtocol.roku;
        } else if (lower.contains('samsung')) {
          proto = RemoteProtocol.samsung;
        } else if (lower.contains('lge') || lower.contains('webos')) {
          proto = RemoteProtocol.lg;
        }
        if (proto != null) {
          classified.putIfAbsent(host, () => proto!);
          final id = ssdpDeviceId(text);
          if (id != null) ids.putIfAbsent(host, () => id);
        }
      });
      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;

      for (final entry in classified.entries) {
        final host = entry.key;
        final proto = entry.value;
        // Roku exposes a serial in device-info — the most stable id we can get.
        String name;
        String deviceId = ids[host] ?? '';
        if (proto == RemoteProtocol.roku) {
          final info = await _rokuInfo(host);
          name = info?.name ?? 'Roku';
          if (info?.serial != null && info!.serial!.isNotEmpty) {
            deviceId = 'roku:${info.serial}';
          }
        } else {
          name = proto.label;
        }
        found['$proto:$host'] = DiscoveredTv(
          name: name,
          host: host,
          port: proto.defaultPort,
          protocol: proto,
          deviceId: deviceId,
        );
      }
    } catch (_) {
      // ignore
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  /// Extracts a stable device identity from an SSDP response. Prefers the UUID
  /// in the USN header (`USN: uuid:<uuid>::...`), which a device keeps across IP
  /// changes. Returns null if no UUID is present. Pure for unit testing.
  static String? ssdpDeviceId(String response) {
    final usn = RegExp(r'USN:\s*uuid:([0-9a-fA-F-]+)', caseSensitive: false)
        .firstMatch(response);
    if (usn != null) return 'uuid:${usn.group(1)!.toLowerCase()}';
    // Some responders only carry the uuid in the ST/SERVER lines.
    final any = RegExp(r'uuid:([0-9a-fA-F]{8}-[0-9a-fA-F-]+)')
        .firstMatch(response);
    return any != null ? 'uuid:${any.group(1)!.toLowerCase()}' : null;
  }

  static Future<_RokuInfo?> _rokuInfo(String host) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client
          .getUrl(Uri.parse('http://$host:8060/query/device-info'))
          .timeout(const Duration(seconds: 2));
      final resp = await req.close().timeout(const Duration(seconds: 2));
      final body = await resp
          .fold<List<int>>([], (a, b) => a..addAll(b))
          .timeout(const Duration(seconds: 2));
      final text = String.fromCharCodes(body);
      final m = RegExp(r'<user-device-name>([^<]*)</user-device-name>')
              .firstMatch(text) ??
          RegExp(r'<friendly-device-name>([^<]*)</friendly-device-name>')
              .firstMatch(text) ??
          RegExp(r'<model-name>([^<]*)</model-name>').firstMatch(text);
      final name = m?.group(1)?.trim();
      final serial =
          RegExp(r'<serial-number>([^<]*)</serial-number>').firstMatch(text);
      return _RokuInfo(
        name: (name != null && name.isNotEmpty) ? name : null,
        serial: serial?.group(1)?.trim(),
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<DiscoveredTv>> _discoverType(
    String serviceType,
    RemoteProtocol protocol,
    Duration timeout,
  ) async {
    final client = MDnsClient();
    final found = <String, DiscoveredTv>{};
    try {
      await client.start();
      await for (final ptr in client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
          )
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          // For CVTE, the TXT record may carry websocket_port + device_name.
          String? wsPort;
          String? txtName;
          if (protocol == RemoteProtocol.cvte) {
            await for (final txt in client.lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(ptr.domainName),
            )) {
              final map = _parseTxt(txt.text);
              wsPort ??= map['websocket_port'];
              txtName ??= map['device_name'];
            }
          }
          await for (final a in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            final name = (txtName != null && txtName.isNotEmpty)
                ? txtName
                : _instanceName(ptr.domainName, serviceType);
            final port = protocol == RemoteProtocol.cvte
                ? (int.tryParse(wsPort ?? '') ?? srv.port)
                : srv.port;
            // The mDNS service instance name is stable across IP changes — a
            // device keeps its advertised name when its DHCP lease moves.
            found[a.address.address] = DiscoveredTv(
              name: name,
              host: a.address.address,
              port: port,
              protocol: protocol,
              deviceId: 'mdns:${ptr.domainName}',
            );
          }
        }
      }
    } catch (_) {
      // ignore — return whatever we found
    } finally {
      client.stop();
    }
    return found.values.toList();
  }

  static Map<String, String> _parseTxt(String txt) {
    final map = <String, String>{};
    for (final entry in txt.split(RegExp(r'[\r\n]+'))) {
      final i = entry.indexOf('=');
      if (i > 0) map[entry.substring(0, i)] = entry.substring(i + 1);
    }
    return map;
  }

  static String _instanceName(String domainName, String serviceType) {
    final idx = domainName.indexOf('.$serviceType');
    final raw = idx > 0 ? domainName.substring(0, idx) : domainName;
    return raw.replaceAll(r'\032', ' ').trim();
  }
}

/// Name + serial parsed from a Roku's /query/device-info.
class _RokuInfo {
  final String? name;
  final String? serial;
  const _RokuInfo({this.name, this.serial});
}
