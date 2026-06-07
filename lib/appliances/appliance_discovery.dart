import 'dart:async';
import 'dart:io';

import '../atv/log.dart';
import 'appliance.dart';

/// A discovered appliance hub or smart device on the local network.
class DiscoveredHub {
  final String name;
  final String host;
  final int port;
  final ApplianceTransport transport;

  /// Best-guess brand/protocol id (e.g. 'broadlink', 'tuya', 'wifi').
  final String brand;

  const DiscoveredHub({
    required this.name,
    required this.host,
    required this.port,
    required this.transport,
    this.brand = '',
  });
}

/// Finds Wi-Fi IR hubs and smart appliances on the LAN. Tries the well-known
/// discovery channels in parallel and returns whatever answers within [timeout].
/// Built-in IR needs no discovery, so it's not handled here.
class ApplianceDiscovery {
  static Future<List<DiscoveredHub>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final results = await Future.wait([
      _discoverBroadlink(timeout),
      _discoverTuya(timeout),
    ]);
    // De-duplicate by host.
    final merged = <String, DiscoveredHub>{};
    for (final list in results) {
      for (final h in list) {
        merged[h.host] = h;
      }
    }
    return merged.values.toList();
  }

  /// Broadlink hubs answer a 0x80-byte discovery datagram broadcast to :80.
  /// We send the well-known probe and treat any responder as a hub, reading its
  /// address from the source of the reply.
  static Future<List<DiscoveredHub>> _discoverBroadlink(
      Duration timeout) async {
    final found = <String, DiscoveredHub>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      // Minimal Broadlink discovery packet: a 0x30-byte frame whose command
      // byte (offset 0x26) is 6. The hub replies from its own IP.
      final packet = List<int>.filled(0x30, 0);
      packet[0x26] = 6;
      final completer = Completer<void>();
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;
        final host = dg.address.address;
        found.putIfAbsent(
          host,
          () => DiscoveredHub(
            name: 'Broadlink',
            host: host,
            port: 80,
            transport: ApplianceTransport.irHub,
            brand: 'broadlink',
          ),
        );
      });
      socket.send(packet, InternetAddress('255.255.255.255'), 80);
      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      await sub.cancel();
    } catch (e) {
      atvLog('appliance discover broadlink', e);
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  /// Tuya devices broadcast UDP JSON beacons on port 6666 (and 6667 encrypted).
  /// We just listen for a beacon and record the sender as a Wi-Fi appliance.
  static Future<List<DiscoveredHub>> _discoverTuya(Duration timeout) async {
    final found = <String, DiscoveredHub>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 6666);
      socket.broadcastEnabled = true;
      final completer = Completer<void>();
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;
        final host = dg.address.address;
        found.putIfAbsent(
          host,
          () => DiscoveredHub(
            name: 'Tuya device',
            host: host,
            port: 0,
            transport: ApplianceTransport.wifi,
            brand: 'tuya',
          ),
        );
      });
      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
      await sub.cancel();
    } catch (e) {
      // Port 6666 may be busy; that's fine — just no Tuya results.
      atvLog('appliance discover tuya', e);
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }
}
