import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend.dart';
import 'key_codes.dart';
import 'log.dart';

/// Samsung Tizen TV remote over WebSocket.
///
/// Connects to `wss://<host>:8002/api/v2/channels/samsung.remote.control`
/// with a base64 `name` query. The first connection prompts the user on the
/// TV to allow the remote; the TV then sends a `token` (in an
/// `ms.channel.connect` message) which we persist and reuse on later
/// connections (appended as `&token=<token>`).
///
/// Keys are sent as JSON:
///   {"method":"ms.remote.control",
///    "params":{"Cmd":"Click","DataOfCmd":"KEY_VOLUP",
///              "Option":"false","TypeOfRemote":"SendRemoteKey"}}
class SamsungBackend implements RemoteBackend {
  final String host;
  final int port;
  String? token;

  /// Called when the TV issues a (new) token so the controller can persist it.
  final void Function(String token)? onToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  Completer<void>? _ready;

  SamsungBackend({
    required this.host,
    this.port = 8002,
    this.token,
    this.onToken,
  });

  @override
  RemoteProtocol get protocol => RemoteProtocol.samsung;

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

  // App display name shown on the TV during authorization.
  static final String _name = base64.encode(utf8.encode('TV Remote'));

  @override
  Future<void> connect() async {
    _setState(RemoteConnectionState.connecting);
    try {
      var url = 'wss://$host:$port/api/v2/channels/samsung.remote.control'
          '?name=$_name';
      if (token != null && token!.isNotEmpty) url += '&token=$token';

      // Samsung uses a self-signed cert on 8002 — accept it.
      final insecure = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      insecure.badCertificateCallback = (cert, h, p) => true;
      final channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        connectTimeout: const Duration(seconds: 8),
        customClient: insecure,
        pingInterval: const Duration(seconds: 20),
      );
      await channel.ready.timeout(const Duration(seconds: 10));
      _channel = channel;
      _ready = Completer<void>();
      _sub = channel.stream.listen(_onMessage,
          onError: (_) => _onClose(), onDone: _onClose);

      // Wait for ms.channel.connect (authorization granted) before "connected".
      await _ready!.future.timeout(const Duration(seconds: 30),
          onTimeout: () => throw const SamsungAuthTimeout());
      _setState(RemoteConnectionState.connected);
    } catch (e) {
      _setState(RemoteConnectionState.disconnected);
      rethrow;
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'];
      if (event == 'ms.channel.connect') {
        // Grab the token if present (first-time authorization).
        final data = msg['data'];
        if (data is Map && data['token'] != null) {
          final t = data['token'].toString();
          token = t;
          onToken?.call(t);
        }
        if (_ready != null && !_ready!.isCompleted) _ready!.complete();
      } else if (event == 'ms.channel.unauthorized') {
        if (_ready != null && !_ready!.isCompleted) {
          _ready!.completeError(const SamsungUnauthorized());
        }
      }
    } catch (e) {
      atvLog('samsung onMessage', e);
    }
  }

  void _onClose() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.completeError(const SamsungUnauthorized());
    }
    _setState(RemoteConnectionState.disconnected);
  }

  void _sendKey(String key) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': key,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    }));
  }

  static String? samsungKeyFor(int keyCode) {
    switch (keyCode) {
      case KeyCode.dpadUp:
        return 'KEY_UP';
      case KeyCode.dpadDown:
        return 'KEY_DOWN';
      case KeyCode.dpadLeft:
        return 'KEY_LEFT';
      case KeyCode.dpadRight:
        return 'KEY_RIGHT';
      case KeyCode.dpadCenter:
        return 'KEY_ENTER';
      case KeyCode.home:
        return 'KEY_HOME';
      case KeyCode.back:
        return 'KEY_RETURN';
      case KeyCode.power:
        return 'KEY_POWER';
      case KeyCode.volumeUp:
        return 'KEY_VOLUP';
      case KeyCode.volumeDown:
        return 'KEY_VOLDOWN';
      case KeyCode.volumeMute:
      case KeyCode.mute:
        return 'KEY_MUTE';
      case KeyCode.channelUp:
        return 'KEY_CHUP';
      case KeyCode.channelDown:
        return 'KEY_CHDOWN';
      case KeyCode.mediaPlayPause:
      case KeyCode.mediaPlay:
        return 'KEY_PLAY';
      case KeyCode.mediaPause:
        return 'KEY_PAUSE';
      case KeyCode.mediaRewind:
        return 'KEY_REWIND';
      case KeyCode.mediaFastForward:
        return 'KEY_FF';
      case KeyCode.menu:
        return 'KEY_MENU';
      case KeyCode.info:
        return 'KEY_INFO';
      case KeyCode.guide:
        return 'KEY_GUIDE';
      case KeyCode.input:
        return 'KEY_SOURCE';
      default:
        if (keyCode >= 7 && keyCode <= 16) return 'KEY_${keyCode - 7}';
        return null;
    }
  }

  @override
  void sendKey(int keyCode) {
    final k = samsungKeyFor(keyCode);
    if (k != null) _sendKey(k);
  }

  @override
  void launchApp(String uri) {
    // Tizen app launch uses a different channel; left as a no-op for now.
  }

  @override
  void sendText(String text) {
    // Samsung text input uses base64 IME messages; out of scope here.
  }

  @override
  void backspace() => _sendKey('KEY_RETURN');
  @override
  void enter() => _sendKey('KEY_ENTER');
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
  void disconnect() {
    _channel?.sink.close();
    _onClose();
  }

  @override
  void dispose() {
    disconnect();
    if (!_stateController.isClosed) _stateController.close();
  }
}

class SamsungAuthTimeout implements Exception {
  const SamsungAuthTimeout();
  @override
  String toString() =>
      'Samsung TV authorization timed out — approve the remote on the TV.';
}

class SamsungUnauthorized implements Exception {
  const SamsungUnauthorized();
  @override
  String toString() => 'Samsung TV refused the remote (unauthorized).';
}
