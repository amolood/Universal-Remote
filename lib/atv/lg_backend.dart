import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'backend.dart';
import 'key_codes.dart';
import 'log.dart';

/// LG webOS TV remote over SSAP (Simple Service Access Protocol).
///
/// Flow:
///   1. WebSocket connect to `ws://<host>:3000`
///   2. Send a `register` message with a permissions manifest. The first time
///      the TV shows an on-screen prompt; on accept it returns a `client-key`
///      which we persist and reuse (skips the prompt next time).
///   3. Volume/mute go via `request` messages (ssap://audio/...).
///   4. D-pad / OK / Back / Home go through a secondary "pointer input" socket
///      obtained from ssap://com.webos.service.networkinput/getPointerInputSocket,
///      sending `type:button\nname:UP\n\n` frames.
class LgBackend implements RemoteBackend {
  final String host;
  final int port;
  String? clientKey;
  final void Function(String key)? onClientKey;

  WebSocketChannel? _channel;
  WebSocketChannel? _pointer;
  StreamSubscription? _sub;
  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;
  Completer<void>? _registered;
  int _cid = 0;

  LgBackend({
    required this.host,
    this.port = 3000,
    this.clientKey,
    this.onClientKey,
  });

  @override
  RemoteProtocol get protocol => RemoteProtocol.lg;
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

  String _nextId() => 'req_${_cid++}';

  // Minimal permission manifest — enough for input/control. (Public protocol
  // shape; no proprietary signature.)
  Map<String, dynamic> get _manifest => {
        'permissions': [
          'CONTROL_INPUT_MEDIA_PLAYBACK',
          'CONTROL_POWER',
          'CONTROL_AUDIO',
          'CONTROL_INPUT_TV',
          'CONTROL_INPUT_JOYSTICK',
          'CONTROL_INPUT_TEXT',
          'LAUNCH',
          'READ_INSTALLED_APPS',
          'CONTROL_DISPLAY',
        ],
      };

  @override
  Future<void> connect() async {
    _setState(RemoteConnectionState.connecting);
    try {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://$host:$port'),
        connectTimeout: const Duration(seconds: 8),
        pingInterval: const Duration(seconds: 20),
      );
      await channel.ready.timeout(const Duration(seconds: 8));
      _channel = channel;
      _registered = Completer<void>();
      _sub = channel.stream.listen(_onMessage,
          onError: (_) => _onClose(), onDone: _onClose);

      // Register (with stored client-key if any).
      final payload = <String, dynamic>{
        'forcePairing': false,
        'pairingType': 'PROMPT',
        'manifest': _manifest,
      };
      if (clientKey != null && clientKey!.isNotEmpty) {
        payload['client-key'] = clientKey;
      }
      channel.sink.add(jsonEncode({
        'id': 'register_0',
        'type': 'register',
        'payload': payload,
      }));

      await _registered!.future.timeout(const Duration(seconds: 30),
          onTimeout: () => throw const LgAuthTimeout());

      // Open the pointer input socket for button presses.
      await _openPointerSocket();
      _setState(RemoteConnectionState.connected);
    } catch (e) {
      _setState(RemoteConnectionState.disconnected);
      rethrow;
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'];
      if (type == 'registered') {
        final payload = msg['payload'];
        if (payload is Map && payload['client-key'] != null) {
          clientKey = payload['client-key'].toString();
          onClientKey?.call(clientKey!);
        }
        if (_registered != null && !_registered!.isCompleted) {
          _registered!.complete();
        }
      } else if (type == 'error') {
        if (_registered != null && !_registered!.isCompleted) {
          _registered!.completeError(const LgUnauthorized());
        }
      } else if (type == 'response' && _pointerCompleter != null) {
        // Response to getPointerInputSocket -> contains the socket path.
        final sock = msg['payload']?['socketPath'];
        if (sock != null && !_pointerCompleter!.isCompleted) {
          _pointerCompleter!.complete(sock.toString());
        }
      }
    } catch (_) {/* ignore */}
  }

  Completer<String>? _pointerCompleter;

  Future<void> _openPointerSocket() async {
    final ch = _channel;
    if (ch == null) return;
    _pointerCompleter = Completer<String>();
    ch.sink.add(jsonEncode({
      'id': _nextId(),
      'type': 'request',
      'uri': 'ssap://com.webos.service.networkinput/getPointerInputSocket',
    }));
    try {
      final path = await _pointerCompleter!.future
          .timeout(const Duration(seconds: 6));
      // socketPath is a wss:// URL; downgrade to ws if needed and connect.
      final uri = Uri.parse(path);
      _pointer = IOWebSocketChannel.connect(uri,
          connectTimeout: const Duration(seconds: 6));
      await _pointer!.ready.timeout(const Duration(seconds: 6));
    } catch (e) {
      _pointer = null; // pointer optional; volume still works via requests
      atvLog('lg pointer socket', e);
    } finally {
      _pointerCompleter = null;
    }
  }

  void _onClose() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _pointer?.sink.close();
    _pointer = null;
    if (_registered != null && !_registered!.isCompleted) {
      _registered!.completeError(const LgUnauthorized());
    }
    _setState(RemoteConnectionState.disconnected);
  }

  void _request(String uri, [Map<String, dynamic>? payload]) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode({
      'id': _nextId(),
      'type': 'request',
      'uri': uri,
      if (payload != null) 'payload': payload,
    }));
  }

  void _button(String name) {
    final p = _pointer;
    if (p == null) return;
    p.sink.add('type:button\nname:$name\n\n');
  }

  @override
  void sendKey(int keyCode) {
    switch (keyCode) {
      case KeyCode.dpadUp:
        _button('UP');
        break;
      case KeyCode.dpadDown:
        _button('DOWN');
        break;
      case KeyCode.dpadLeft:
        _button('LEFT');
        break;
      case KeyCode.dpadRight:
        _button('RIGHT');
        break;
      case KeyCode.dpadCenter:
        _button('ENTER');
        break;
      case KeyCode.back:
        _button('BACK');
        break;
      case KeyCode.home:
        _button('HOME');
        break;
      case KeyCode.menu:
        _button('MENU');
        break;
      case KeyCode.info:
        _button('INFO');
        break;
      case KeyCode.volumeUp:
        _request('ssap://audio/volumeUp');
        break;
      case KeyCode.volumeDown:
        _request('ssap://audio/volumeDown');
        break;
      case KeyCode.volumeMute:
      case KeyCode.mute:
        _request('ssap://audio/setMute', {'mute': true});
        break;
      case KeyCode.channelUp:
        _request('ssap://tv/channelUp');
        break;
      case KeyCode.channelDown:
        _request('ssap://tv/channelDown');
        break;
      case KeyCode.power:
        _request('ssap://system/turnOff');
        break;
      case KeyCode.mediaPlayPause:
      case KeyCode.mediaPlay:
        _request('ssap://media.controls/play');
        break;
      case KeyCode.mediaPause:
        _request('ssap://media.controls/pause');
        break;
      default:
        if (keyCode >= 7 && keyCode <= 16) _button('${keyCode - 7}');
    }
  }

  @override
  void launchApp(String uri) {
    _request('ssap://system.launcher/launch', {'id': uri});
  }

  @override
  void sendText(String text) {
    _request('ssap://com.webos.service.ime/insertText',
        {'text': text, 'replace': false});
  }

  @override
  void backspace() =>
      _request('ssap://com.webos.service.ime/deleteCharacters', {'count': 1});
  @override
  void enter() => _request('ssap://com.webos.service.ime/sendEnterKey');
  @override
  void moveCursor(double dx, double dy) {
    final p = _pointer;
    if (p == null) return;
    p.sink.add('type:move\ndx:${dx.round()}\ndy:${dy.round()}\ndown:0\n\n');
  }

  @override
  void click() => _button('ENTER');
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

class LgAuthTimeout implements Exception {
  const LgAuthTimeout();
  @override
  String toString() =>
      'LG TV authorization timed out — accept the prompt on the TV.';
}

class LgUnauthorized implements Exception {
  const LgUnauthorized();
  @override
  String toString() => 'LG TV refused the remote (unauthorized).';
}
