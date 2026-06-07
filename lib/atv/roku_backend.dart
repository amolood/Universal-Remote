import 'dart:async';
import 'dart:io';

import 'backend.dart';
import 'key_codes.dart';
import 'log.dart';

/// An app installed on a Roku device (from /query/apps).
class RokuApp {
  final String id;
  final String name;
  const RokuApp(this.id, this.name);

  /// Icon URL on the Roku itself: `GET /query/icon/<id>`.
  String iconUrl(String host, int port) => 'http://$host:$port/query/icon/$id';
}

/// Roku External Control Protocol (ECP) backend.
///
/// ECP is plain HTTP on port 8060 — no pairing, no TLS:
///   - `POST /keypress/<Key>`   send a remote key
///   - `POST /launch/<appId>`   open an app
///   - `GET  /query/device-info` device metadata
///
/// Key names are Roku's own (Home, Up, Select, VolumeUp, ...), so we map our
/// Android-style keycodes to them.
class RokuBackend implements RemoteBackend {
  final String host;
  final int port;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  final _stateController =
      StreamController<RemoteConnectionState>.broadcast();
  RemoteConnectionState _state = RemoteConnectionState.disconnected;

  RokuBackend({required this.host, this.port = 8060});

  @override
  RemoteProtocol get protocol => RemoteProtocol.roku;

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
      // ECP is connectionless; "connecting" just means we can reach the box.
      final req = await _http
          .getUrl(Uri.parse('http://$host:$port/query/device-info'))
          .timeout(const Duration(seconds: 4));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
      if (resp.statusCode == 200) {
        _setState(RemoteConnectionState.connected);
      } else {
        _setState(RemoteConnectionState.disconnected);
        throw HttpException('Roku returned ${resp.statusCode}');
      }
    } catch (e) {
      _setState(RemoteConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> _keypress(String key) async {
    try {
      final req = await _http
          .postUrl(Uri.parse('http://$host:$port/keypress/$key'))
          .timeout(const Duration(seconds: 3));
      final resp = await req.close().timeout(const Duration(seconds: 3));
      await resp.drain<void>();
    } catch (e) {
      // A transient failure shouldn't crash the UI; surface via state if lost.
      atvLog('roku keypress $key', e);
    }
  }

  /// Fetches the apps installed on the Roku (GET /query/apps). Each entry is
  /// `<app id="..." ...>Name</app>` in the XML response.
  Future<List<RokuApp>> queryApps() async {
    try {
      final req = await _http
          .getUrl(Uri.parse('http://$host:$port/query/apps'))
          .timeout(const Duration(seconds: 4));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      final body = await resp
          .fold<List<int>>([], (a, b) => a..addAll(b))
          .timeout(const Duration(seconds: 4));
      final text = String.fromCharCodes(body);
      final apps = <RokuApp>[];
      final re = RegExp(r'<app id="([^"]+)"[^>]*>([^<]*)</app>');
      for (final m in re.allMatches(text)) {
        apps.add(RokuApp(m.group(1)!, m.group(2)!.trim()));
      }
      return apps;
    } catch (e) {
      atvLog('roku queryApps', e);
      return const [];
    }
  }

  /// Maps our Android keycodes to Roku ECP key names.
  static String? rokuKeyFor(int keyCode) {
    switch (keyCode) {
      case KeyCode.dpadUp:
        return 'Up';
      case KeyCode.dpadDown:
        return 'Down';
      case KeyCode.dpadLeft:
        return 'Left';
      case KeyCode.dpadRight:
        return 'Right';
      case KeyCode.dpadCenter:
        return 'Select';
      case KeyCode.home:
        return 'Home';
      case KeyCode.back:
        return 'Back';
      case KeyCode.power:
        return 'Power'; // toggles; PowerOff also exists
      case KeyCode.volumeUp:
        return 'VolumeUp';
      case KeyCode.volumeDown:
        return 'VolumeDown';
      case KeyCode.volumeMute:
      case KeyCode.mute:
        return 'VolumeMute';
      case KeyCode.mediaPlayPause:
      case KeyCode.mediaPlay:
      case KeyCode.mediaPause:
        return 'Play';
      case KeyCode.mediaRewind:
        return 'Rev';
      case KeyCode.mediaFastForward:
        return 'Fwd';
      case KeyCode.mediaNext:
        return 'Fwd';
      case KeyCode.mediaPrevious:
        return 'Rev';
      case KeyCode.channelUp:
        return 'ChannelUp';
      case KeyCode.channelDown:
        return 'ChannelDown';
      case KeyCode.info:
        return 'Info';
      case KeyCode.search:
        return 'Search';
      case KeyCode.input:
        return 'InputHDMI1';
      default:
        // Digits 0-9 -> Lit_<digit>
        if (keyCode >= 7 && keyCode <= 16) return 'Lit_${keyCode - 7}';
        return null;
    }
  }

  @override
  void sendKey(int keyCode) {
    final key = rokuKeyFor(keyCode);
    if (key != null) _keypress(key);
  }

  @override
  void launchApp(String uri) {
    // For Roku, `uri` is expected to be an app/channel id.
    final id = uri.replaceAll(RegExp(r'[^0-9]'), '');
    if (id.isNotEmpty) {
      _http
          .postUrl(Uri.parse('http://$host:$port/launch/$id'))
          .then((r) => r.close())
          .then((r) => r.drain<void>())
          .catchError((Object e) => atvLog('roku launch $id', e));
    }
  }

  @override
  void sendText(String text) {
    // Roku types via per-character Lit_ keypresses (URL-encoded).
    for (final ch in text.split('')) {
      _keypress('Lit_${Uri.encodeComponent(ch)}');
    }
  }

  @override
  void backspace() => _keypress('Backspace');

  @override
  void enter() => _keypress('Enter');

  @override
  void moveCursor(double dx, double dy) {}

  @override
  void click() => sendKey(KeyCode.dpadCenter);

  // Roku has no voice channel in ECP.
  @override
  Future<bool> startVoice() async => false;
  @override
  void sendVoiceChunk(List<int> pcm) {}
  @override
  void endVoice() {}

  @override
  void disconnect() {
    _setState(RemoteConnectionState.disconnected);
  }

  @override
  void dispose() {
    _http.close(force: true);
    if (!_stateController.isClosed) _stateController.close();
  }
}
