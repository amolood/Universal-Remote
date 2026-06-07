import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../proto/protobuf.dart';
import 'backend.dart';

/// CVTE / Bytello control protocol.
///
/// Reverse-engineered from the Bytello Remote app:
///   - Transport: WebSocket  `ws://<ip>:<port>`  (no TLS, no pairing cert)
///   - Messages: protobuf  `Message{ type:int32=1, action:string=2,
///       repeated Pointer pointers=3, bytes=4 }`  `Pointer{ float x=1, float y=2 }`
///   - type is the ordinal of the RemoteEvent enum (see [CvteEvent]).
///   - A key press is  `type=KEY_EVENT(1), action="<android keycode>"`.
class CvteEvent {
  static const int keyEvent = 1;
  static const int mouseMoveEvent = 3;
  static const int mouseClickEvent = 4;
  static const int keyboardShowEvent = 6;
  static const int keyboardHideEvent = 7;
  static const int voiceContent = 9;
  static const int voiceFinish = 10;
  static const int voiceStart = 13;
  static const int googleVoiceStart = 15;
  static const int googleVoiceFinish = 16;
}

/// Encodes CVTE protobuf control messages.
class CvteMessages {
  /// Message{ type=1 (int32), action=2 (string), pointers=3, bytes=4 }
  static Uint8List event({
    required int type,
    String? action,
    List<(double, double)> pointers = const [],
  }) {
    final w = ProtoWriter();
    if (type != 0) w.writeInt(1, type);
    if (action != null && action.isNotEmpty) w.writeString(2, action);
    for (final (x, y) in pointers) {
      final p = ProtoWriter()
        ..writeFloat(1, x)
        ..writeFloat(2, y);
      w.writeMessage(3, p); // repeated Pointer
    }
    return w.toBytes();
  }

  static Uint8List key(int keyCode) =>
      event(type: CvteEvent.keyEvent, action: '$keyCode');

  static Uint8List mouseMove(double x, double y) =>
      event(type: CvteEvent.mouseMoveEvent, pointers: [(x, y)]);

  static Uint8List mouseClick() => event(type: CvteEvent.mouseClickEvent);

  static Uint8List keyboardShow() => event(type: CvteEvent.keyboardShowEvent);
}

/// CVTE control backend over WebSocket.
class CvteBackend implements RemoteBackend {
  final String host;
  final int port;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;

  CvteBackend({required this.host, required this.port});

  @override
  RemoteProtocol get protocol => RemoteProtocol.cvte;

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
    try {
      final uri = Uri.parse('ws://$host:$port');
      // IOWebSocketChannel with a pingInterval keeps the connection alive and
      // detects a dead TV quickly: if a pong isn't received within the
      // interval, the socket closes -> onDone fires -> the controller's
      // auto-reconnect kicks in.
      final channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 10),
        connectTimeout: const Duration(seconds: 8),
      );
      await channel.ready.timeout(const Duration(seconds: 8));
      _channel = channel;
      _sub = channel.stream.listen(
        (_) {/* TV->phone messages (status); not needed for control */},
        onError: (_) => _onClose(),
        onDone: _onClose,
      );
      _setState(RemoteConnectionState.connected);
    } catch (e) {
      _setState(RemoteConnectionState.disconnected);
      rethrow;
    }
  }

  void _onClose() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _setState(RemoteConnectionState.disconnected);
  }

  void _send(Uint8List bytes) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(bytes); // binary frame
  }

  @override
  void sendKey(int keyCode) => _send(CvteMessages.key(keyCode));

  @override
  void moveCursor(double dx, double dy) =>
      _send(CvteMessages.mouseMove(dx, dy));

  @override
  void click() => _send(CvteMessages.mouseClick());

  @override
  void launchApp(String uri) {
    // CVTE has no documented deep-link channel in the captured protocol; the
    // closest analog is sending the URL as a key/action sequence. Skipped to
    // avoid sending malformed commands. (Apps row hidden for CVTE in the UI.)
  }

  @override
  void sendText(String text) {
    // CVTE accepts characters as individual key events, same as Android.
    for (final ch in text.split('')) {
      final code = _androidKeyForChar(ch);
      if (code != null) sendKey(code);
    }
  }

  @override
  void backspace() => sendKey(67); // KEYCODE_DEL

  @override
  void enter() => sendKey(66); // KEYCODE_ENTER

  // CVTE voice isn't implemented in this build.
  @override
  Future<bool> startVoice() async => false;
  @override
  void sendVoiceChunk(List<int> pcm) {}
  @override
  void endVoice() {}

  @override
  void disconnect() {
    _channel?.sink.close(ws_status.normalClosure);
    _onClose();
  }

  @override
  void dispose() {
    disconnect();
    if (!_stateController.isClosed) _stateController.close();
  }

  int? _androidKeyForChar(String ch) {
    if (ch.isEmpty) return null;
    final code = ch.toLowerCase().codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7a) return 29 + (code - 0x61); // a-z
    if (code >= 0x30 && code <= 0x39) return 7 + (code - 0x30); // 0-9
    if (ch == ' ') return 62;
    return null;
  }
}
