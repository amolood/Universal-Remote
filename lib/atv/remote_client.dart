import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'framing.dart';
import 'key_codes.dart';
import 'messages.dart';

enum RemoteConnectionState { disconnected, connecting, connected }

/// Thrown when the TV accepts the TLS socket but never starts the control
/// handshake — i.e. it no longer recognises our certificate and we must pair.
class RemoteNotPairedException implements Exception {
  const RemoteNotPairedException();
  @override
  String toString() => 'TV did not accept the connection (not paired)';
}

/// Thrown when the TV doesn't open a voice session (voice not supported / busy).
class RemoteVoiceUnavailable implements Exception {
  const RemoteVoiceUnavailable();
  @override
  String toString() => 'Voice search isn\'t available on this TV';
}

/// Persistent control connection to the Android TV on port 6466.
///
/// After connecting (presenting the same client cert used for pairing) the TV
/// sends a configure request; we reply with our device info and set_active,
/// then keep the socket open, answering pings, and send key/app messages on
/// demand.
class RemoteClient {
  static const int port = 6466;

  final String host;
  final SecurityContext context;

  SecureSocket? _socket;
  final MessageFramer _framer = MessageFramer();
  StreamSubscription? _sub;

  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;

  RemoteClient({required this.host, required this.context});

  RemoteConnectionState get state => _state;
  Stream<RemoteConnectionState> get stateStream => _stateController.stream;

  void _setState(RemoteConnectionState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  // Completes once the TV sends its first handshake message (proof that it
  // recognises our certificate). Used to distinguish a real paired connection
  // from a bare TLS socket the TV will silently drop.
  Completer<void>? _handshake;

  Future<void> connect() async {
    _setState(RemoteConnectionState.connecting);
    try {
      _socket = await SecureSocket.connect(
        host,
        port,
        context: context,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _setState(RemoteConnectionState.disconnected);
      rethrow;
    }
    _handshake = Completer<void>();
    _sub = _socket!.listen(
      _onData,
      onError: (_) => _onClose(),
      onDone: _onClose,
    );

    // Wait for the TV to begin the control handshake. An unpaired client gets
    // its socket dropped without any message, so a timeout/close => not paired.
    try {
      await _handshake!.future.timeout(const Duration(seconds: 6));
    } catch (_) {
      _onClose();
      throw const RemoteNotPairedException();
    }
    // The TV can send its first message and close the socket in the same
    // event-loop turn; if _onClose already tore us down, don't announce a
    // "connected" state that immediately reverts to disconnected.
    if (_socket == null) throw const RemoteNotPairedException();
    _setState(RemoteConnectionState.connected);
  }

  void _onData(Uint8List data) {
    for (final payload in _framer.addBytes(data)) {
      final msg = RemoteIncoming.parse(payload);
      // Any valid message from the TV proves the handshake started.
      if (_handshake != null && !_handshake!.isCompleted) {
        _handshake!.complete();
      }
      switch (msg.field) {
        case 1: // remote_configure -> reply with our configure
          _raw(RemoteMessages.configure());
          break;
        case 2: // remote_set_active -> echo active features back
          _raw(RemoteMessages.setActive(RemoteMessages.activeFeatures));
          break;
        case 8: // remote_ping_request -> ping_response
          _raw(RemoteMessages.pingResponse(msg.pingVal ?? 1));
          break;
        case 30: // remote_voice_begin -> session is ready
          final sid = msg.voiceSessionId ?? 0;
          if (_voiceBegin != null && !_voiceBegin!.isCompleted) {
            _voiceBegin!.complete(sid);
          }
          break;
        default:
          // remote_start, volume updates, ime, errors, etc. — no action.
          break;
      }
    }
  }

  void _onClose() {
    if (_handshake != null && !_handshake!.isCompleted) {
      _handshake!.completeError(const RemoteNotPairedException());
    }
    _sub?.cancel();
    _sub = null;
    _socket?.destroy();
    _socket = null;
    _setState(RemoteConnectionState.disconnected);
  }

  void _raw(Uint8List payload) {
    final s = _socket;
    if (s == null) return;
    s.add(frame(payload));
  }

  // --- public control surface ---

  /// Sends a key press (a SHORT down+up). The TV expects START_LONG/END_LONG
  /// pairs or a single SHORT; SHORT works for taps.
  void sendKey(int keyCode) {
    _raw(RemoteMessages.keyInject(
      keyCode: keyCode,
      direction: KeyDirection.short,
    ));
  }

  /// Press-and-hold start.
  void keyDown(int keyCode) {
    _raw(RemoteMessages.keyInject(
      keyCode: keyCode,
      direction: KeyDirection.startLong,
    ));
  }

  /// Press-and-hold release.
  void keyUp(int keyCode) {
    _raw(RemoteMessages.keyInject(
      keyCode: keyCode,
      direction: KeyDirection.endLong,
    ));
  }

  /// Launches an app via deep link.
  void launchApp(String uri) => _raw(RemoteMessages.appLink(uri));

  /// Types text into the focused field on the TV by sending one key event per
  /// character. Characters with no direct keycode are skipped.
  void sendText(String text) {
    for (final ch in text.split('')) {
      final code = keyCodeForChar(ch);
      if (code != null) sendKey(code);
    }
  }

  /// Sends a backspace.
  void backspace() => sendKey(keyCodeDelete);

  /// Sends enter / confirm.
  void enter() => sendKey(keyCodeEnter);

  // --- Voice ---

  Completer<int>? _voiceBegin;
  int? _voiceSession;

  /// Starts a voice session: sends KEYCODE_SEARCH, waits for the TV's
  /// remote_voice_begin, echoes it back, and returns the session id. Throws on
  /// timeout (TV didn't open a voice session).
  Future<int> startVoice() async {
    if (_socket == null) throw const RemoteNotPairedException();
    _voiceBegin = Completer<int>();
    sendKey(84); // KEYCODE_SEARCH triggers the voice session
    final sid = await _voiceBegin!.future
        .timeout(const Duration(seconds: 5), onTimeout: () => -1);
    if (sid < 0) {
      _voiceBegin = null;
      throw const RemoteVoiceUnavailable();
    }
    _voiceSession = sid;
    _voiceBuf.clear();
    _raw(RemoteMessages.voiceBegin(sid)); // echo begin -> ready to stream
    return sid;
  }

  // The reference client reads 8192-frame buffers = 16KB of 16-bit audio per
  // chunk. `record` delivers tiny ~1.28KB buffers, so we accumulate to ~16KB
  // contiguous frames (between the TV's 8KB min and 20KB max) and never pad
  // mid-stream — padding sub-min chunks would inject silence gaps that garble
  // recognition.
  static const int _voiceFrame = 16 * 1024;
  static const int _voiceMax = 20 * 1024;
  final BytesBuilder _voiceBuf = BytesBuilder();

  /// Streams live 16-bit PCM (8kHz mono). Accumulates and emits contiguous
  /// 8KB frames as soon as enough audio is available (low latency), splitting
  /// anything over 20KB. No mid-stream zero-padding — frames stay valid,
  /// continuous PCM so the TV's recognizer hears uninterrupted speech.
  void sendVoiceChunk(List<int> pcm) {
    if (_voiceSession == null) return;
    _voiceBuf.add(pcm);
    while (_voiceBuf.length >= _voiceFrame) {
      final all = _voiceBuf.takeBytes();
      final take = all.length > _voiceMax ? _voiceMax : all.length;
      _raw(RemoteMessages.voicePayload(_voiceSession!, all.sublist(0, take)));
      if (take < all.length) _voiceBuf.add(all.sublist(take));
    }
  }

  /// Ends the active voice session, flushing any buffered tail (zero-padded to
  /// the minimum frame size, as the reference client does).
  void endVoice() {
    final sid = _voiceSession;
    if (sid != null) {
      if (_voiceBuf.length > 0) {
        var tail = _voiceBuf.takeBytes();
        if (tail.length < _voiceFrame) {
          tail = Uint8List(_voiceFrame)..setRange(0, tail.length, tail);
        }
        _raw(RemoteMessages.voicePayload(sid, tail));
      }
      _raw(RemoteMessages.voiceEnd(sid));
    }
    _voiceBuf.clear();
    _voiceSession = null;
    _voiceBegin = null;
  }

  void disconnect() => _onClose();

  void dispose() {
    _onClose();
    _stateController.close();
  }
}
