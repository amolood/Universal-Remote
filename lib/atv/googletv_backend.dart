import 'dart:io';

import 'backend.dart';
import 'key_codes.dart';
import 'remote_client.dart';

/// Adapts the existing Google/Android TV [RemoteClient] to [RemoteBackend].
class GoogleTvBackend implements RemoteBackend {
  final RemoteClient _client;

  GoogleTvBackend({required String host, required SecurityContext context})
      : _client = RemoteClient(host: host, context: context);

  @override
  RemoteProtocol get protocol => RemoteProtocol.googleTv;

  @override
  Stream<RemoteConnectionState> get stateStream => _client.stateStream;

  @override
  RemoteConnectionState get state => _client.state;

  @override
  bool get isConnected => _client.state == RemoteConnectionState.connected;

  @override
  Future<void> connect() => _client.connect();

  @override
  void sendKey(int keyCode) => _client.sendKey(keyCode);

  @override
  void launchApp(String uri) => _client.launchApp(uri);

  @override
  void sendText(String text) => _client.sendText(text);

  @override
  void backspace() => _client.backspace();

  @override
  void enter() => _client.enter();

  // Google TV has no mouse channel; map a click to DPAD_CENTER.
  @override
  void moveCursor(double dx, double dy) {}

  @override
  void click() => _client.sendKey(KeyCode.dpadCenter);

  @override
  Future<bool> startVoice() async {
    try {
      await _client.startVoice();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void sendVoiceChunk(List<int> pcm) => _client.sendVoiceChunk(pcm);

  @override
  void endVoice() => _client.endVoice();

  @override
  void disconnect() => _client.disconnect();

  @override
  void dispose() => _client.dispose();
}
