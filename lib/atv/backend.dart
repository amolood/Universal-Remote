import 'remote_client.dart' show RemoteConnectionState;

export 'remote_client.dart' show RemoteConnectionState, RemoteNotPairedException;

/// The control protocols the app supports.
enum RemoteProtocol {
  /// Google / Android TV Remote v2 (TLS + client cert + pairing code).
  googleTv,

  /// CVTE / Bytello smart boards & TVs (WebSocket + protobuf, no cert).
  cvte,

  /// Roku ECP — plain HTTP keypress commands, no pairing.
  roku,

  /// Samsung Tizen — WebSocket on 8002 (wss) with a per-app token.
  samsung,

  /// LG webOS — SSAP over WebSocket on 3000 with a client-key handshake.
  lg,

  /// Infrared — phone IR blaster (no network); works on legacy TVs.
  ir,
}

extension RemoteProtocolLabel on RemoteProtocol {
  String get label => switch (this) {
        RemoteProtocol.googleTv => 'Android TV',
        RemoteProtocol.cvte => 'Smart Board',
        RemoteProtocol.roku => 'Roku',
        RemoteProtocol.samsung => 'Samsung',
        RemoteProtocol.lg => 'LG',
        RemoteProtocol.ir => 'Infrared',
      };

  /// Default control port for this protocol.
  int get defaultPort => switch (this) {
        RemoteProtocol.googleTv => 6466,
        RemoteProtocol.cvte => 8125,
        RemoteProtocol.roku => 8060,
        RemoteProtocol.samsung => 8002,
        RemoteProtocol.lg => 3000,
        RemoteProtocol.ir => 0,
      };
}

/// A protocol-agnostic remote control connection. Both the Google TV and CVTE
/// backends implement this so the UI and controller never branch on protocol.
abstract class RemoteBackend {
  RemoteProtocol get protocol;

  Stream<RemoteConnectionState> get stateStream;
  RemoteConnectionState get state;
  bool get isConnected;

  /// Opens the control connection. Throws on failure (e.g. not paired).
  Future<void> connect();

  void sendKey(int keyCode);
  void launchApp(String uri);
  void sendText(String text);
  void backspace();
  void enter();

  /// Touchpad relative move (dx, dy in pixels) — used by CVTE air-mouse style
  /// control. Google TV has no mouse channel, so it maps to a no-op there.
  void moveCursor(double dx, double dy) {}

  /// Tap / click at the current cursor (CVTE mouse click). Google TV maps this
  /// to DPAD_CENTER via [sendKey].
  void click() {}

  /// Voice search: open a session (returns true if the TV accepted), stream
  /// 16-bit PCM 8kHz mono chunks, then end. Backends that don't support voice
  /// return false from [startVoice].
  Future<bool> startVoice() async => false;
  void sendVoiceChunk(List<int> pcm) {}
  void endVoice() {}

  void disconnect();
  void dispose();
}
