import 'dart:async';

import 'package:flutter/services.dart';

import 'backend.dart';
import 'key_codes.dart';
import 'log.dart';

/// Infrared backend — drives the phone's IR blaster (if it has one) via a
/// platform channel to Android's ConsumerIrManager. Works on legacy TVs with
/// no network. Uses the NEC protocol with a generic TV code set as a starting
/// point; brand-specific code sets can be added later.
///
/// IR is connectionless: "connected" just means the phone has an IR emitter.
class IrBackend implements RemoteBackend {
  static const _channel = MethodChannel('com.molood.atv_remote/ir');

  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;

  @override
  RemoteProtocol get protocol => RemoteProtocol.ir;
  @override
  RemoteConnectionState get state => _state;
  @override
  Stream<RemoteConnectionState> get stateStream => _stateController.stream;
  @override
  bool get isConnected => _state == RemoteConnectionState.connected;

  void _setState(RemoteConnectionState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  @override
  Future<void> connect() async {
    _setState(RemoteConnectionState.connecting);
    final hasEmitter = await _channel
        .invokeMethod<bool>('hasIrEmitter')
        .catchError((_) => false);
    if (hasEmitter == true) {
      _setState(RemoteConnectionState.connected);
    } else {
      _setState(RemoteConnectionState.disconnected);
      throw const IrUnavailable();
    }
  }

  // NEC frame: 38kHz carrier, generic TV codes (address 0x04). These are a
  // common starting set; brand code sets can be added to the map later.
  static const int _necAddress = 0x04;
  static const Map<int, int> _necCodes = {
    KeyCode.power: 0x08,
    KeyCode.volumeUp: 0x02,
    KeyCode.volumeDown: 0x03,
    KeyCode.mute: 0x09,
    KeyCode.volumeMute: 0x09,
    KeyCode.channelUp: 0x00,
    KeyCode.channelDown: 0x01,
    KeyCode.dpadUp: 0x40,
    KeyCode.dpadDown: 0x41,
    KeyCode.dpadLeft: 0x07,
    KeyCode.dpadRight: 0x06,
    KeyCode.dpadCenter: 0x44,
    KeyCode.back: 0x45,
    KeyCode.home: 0x46,
    KeyCode.menu: 0x47,
  };

  Future<void> _emitNec(int command) async {
    // Build the NEC 38kHz pattern on the native side from address+command.
    try {
      await _channel.invokeMethod('transmitNec', {
        'address': _necAddress,
        'command': command,
        'carrier': 38000,
      });
    } catch (e) {
      atvLog('ir transmitNec $command', e);
    }
  }

  /// The NEC command byte for a keycode, or null if this IR set has no mapping.
  /// Pure and static for unit testing.
  static int? necCodeFor(int keyCode) => _necCodes[keyCode];

  @override
  void sendKey(int keyCode) {
    final code = necCodeFor(keyCode);
    if (code != null) _emitNec(code);
  }

  @override
  void launchApp(String uri) {}
  @override
  void sendText(String text) {}
  @override
  void backspace() {}
  @override
  void enter() => sendKey(KeyCode.dpadCenter);
  @override
  void moveCursor(double dx, double dy) {}
  @override
  void click() => sendKey(KeyCode.dpadCenter);
  @override
  Future<bool> startVoice() async => false;
  @override
  void sendVoiceChunk(List<int> pcm) {}
  @override
  void endVoice() {}

  @override
  void disconnect() => _setState(RemoteConnectionState.disconnected);

  @override
  void dispose() {
    if (!_stateController.isClosed) _stateController.close();
  }
}

class IrUnavailable implements Exception {
  const IrUnavailable();
  @override
  String toString() => 'This phone has no infrared (IR) blaster.';
}
