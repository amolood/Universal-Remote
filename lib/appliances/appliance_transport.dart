import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../atv/log.dart';
import 'appliance.dart';

/// Delivers a control action to an appliance over its chosen transport. AC-style
/// devices send a raw IR pattern; Wi-Fi devices send a brand-specific command.
/// (Named [ApplianceLink] to avoid clashing with the [ApplianceTransport] enum.)
abstract class ApplianceLink {
  /// Sends a raw IR burst (microseconds) at [carrierHz]. Returns false if the
  /// transport can't emit IR or the send failed.
  Future<bool> sendIr(List<int> pattern, int carrierHz);

  /// Sends a high-level Wi-Fi command (transport-specific). Default: unsupported.
  Future<bool> sendWifi(Map<String, dynamic> command) async => false;

  void dispose() {}

  /// Builds the right link for an appliance based on its transport.
  static ApplianceLink forAppliance(Appliance a) {
    switch (a.transport) {
      case ApplianceTransport.builtinIr:
        return BuiltinIrTransport();
      case ApplianceTransport.irHub:
        return IrHubTransport(host: a.host, port: a.port, token: a.secret);
      case ApplianceTransport.wifi:
        return WifiApplianceTransport(
            host: a.host, port: a.port, token: a.secret);
    }
  }
}

/// Transmits IR through the phone's own emitter via the native channel. Reuses
/// the existing IR MethodChannel and its new `transmitRaw` method.
class BuiltinIrTransport extends ApplianceLink {
  static const _channel = MethodChannel('com.molood.atv_remote/ir');

  /// Whether this phone actually has an IR emitter.
  static Future<bool> hasEmitter() async {
    try {
      return await _channel.invokeMethod<bool>('hasIrEmitter') ?? false;
    } catch (e) {
      atvLog('appliance ir hasEmitter', e);
      return false;
    }
  }

  @override
  Future<bool> sendIr(List<int> pattern, int carrierHz) async {
    try {
      final ok = await _channel.invokeMethod<bool>('transmitRaw', {
        'pattern': pattern,
        'carrier': carrierHz,
      });
      return ok ?? false;
    } catch (e) {
      atvLog('appliance builtin-ir send', e);
      return false;
    }
  }
}

/// Sends IR codes to an external Wi-Fi IR blaster which re-emits them. This is a
/// generic HTTP hub adapter: it POSTs the raw pattern as JSON. Concrete hub
/// brands (Broadlink/Tuya) can subclass and override the request shape.
class IrHubTransport extends ApplianceLink {
  final String host;
  final int port;
  final String token;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  IrHubTransport({required this.host, required this.port, this.token = ''});

  @override
  Future<bool> sendIr(List<int> pattern, int carrierHz) async {
    try {
      final uri = Uri.parse('http://$host:${port == 0 ? 80 : port}/ir/send');
      final req = await _http.postUrl(uri).timeout(const Duration(seconds: 4));
      req.headers.contentType = ContentType.json;
      if (token.isNotEmpty) req.headers.add('Authorization', 'Bearer $token');
      req.write(jsonEncode({'carrier': carrierHz, 'pattern': pattern}));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      atvLog('appliance ir-hub send', e);
      return false;
    }
  }

  @override
  void dispose() => _http.close(force: true);
}

/// Controls a native Wi-Fi appliance over HTTP. Generic adapter that POSTs a
/// JSON command; concrete brands (Daikin/Tuya/Midea) override the endpoint and
/// payload shape.
class WifiApplianceTransport extends ApplianceLink {
  final String host;
  final int port;
  final String token;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  WifiApplianceTransport(
      {required this.host, required this.port, this.token = ''});

  // Wi-Fi appliances don't take IR — they speak their own API.
  @override
  Future<bool> sendIr(List<int> pattern, int carrierHz) async => false;

  @override
  Future<bool> sendWifi(Map<String, dynamic> command) async {
    try {
      final uri =
          Uri.parse('http://$host:${port == 0 ? 80 : port}/command');
      final req = await _http.postUrl(uri).timeout(const Duration(seconds: 4));
      req.headers.contentType = ContentType.json;
      if (token.isNotEmpty) req.headers.add('Authorization', 'Bearer $token');
      req.write(jsonEncode(command));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      atvLog('appliance wifi send', e);
      return false;
    }
  }

  @override
  void dispose() => _http.close(force: true);
}
