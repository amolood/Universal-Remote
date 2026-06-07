import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'certificate.dart';
import 'cvte_backend.dart';
import 'cvte_pin.dart';
import 'discovery.dart';
import 'air_mouse.dart';
import 'googletv_backend.dart';
import 'ir_backend.dart';
import 'key_codes.dart';
import 'lg_backend.dart';
import 'log.dart';
import 'roku_backend.dart';
import 'samsung_backend.dart';
import 'paired_tv.dart';
import 'secret_store.dart';
import 'pairing_client.dart';
import 'remote_client.dart';
import 'voice_mic.dart';
import '../i18n/strings.dart';
import '../ui/theme.dart' show Haptics;

export '../i18n/strings.dart' show AppLang, AppLangInfo;

export 'backend.dart' show RemoteProtocol, RemoteProtocolLabel;
export 'roku_backend.dart' show RokuApp;
// RemoteLayout / RemoteLayoutInfo are defined in this file and available to importers.

/// Available remote control layouts the user can pick in Settings.
enum RemoteLayout {
  /// Top utility row, dpad/touchpad, media, volume+channel rails (default).
  balanced,

  /// Big dpad + OK, minimal extras.
  minimal,

  /// Large swipe touchpad with a small button row underneath.
  touchpad,

  /// Classic TV-remote layout: top row, circular D-pad with buttons in its
  /// corners, and vertical Volume/Channel columns on the sides.
  classic,
}

extension RemoteLayoutInfo on RemoteLayout {
  String get label => switch (this) {
        RemoteLayout.balanced => 'Balanced',
        RemoteLayout.minimal => 'Minimal',
        RemoteLayout.touchpad => 'Touchpad',
        RemoteLayout.classic => 'Classic',
      };

  String get description => switch (this) {
        RemoteLayout.balanced =>
          'Full controls: D-pad, media, volume & channels',
        RemoteLayout.minimal => 'Just the essentials — big D-pad & volume',
        RemoteLayout.touchpad => 'Large swipe pad with a compact button row',
        RemoteLayout.classic =>
          'TV-style: D-pad with corner keys, side VOL & CH',
      };
}

/// Which top-level screen the app is showing.
enum AppStage {
  /// Browsing / scanning for TVs (and listing saved ones).
  discovery,

  /// A TV is selected and pairing is in progress; the code-entry UI is shown.
  pairing,

  /// Connected (or attempting to reconnect) to a TV — the remote is shown.
  remote,
}

/// App-wide state: owns the saved TVs, the active pairing session, and the
/// live remote connection. Exposed to the UI via [ChangeNotifier].
class AtvController extends ChangeNotifier {
  static const _kTvs = 'atv_paired_tvs';
  static const _kLayout = 'atv_layout';
  static const _kHaptics = 'atv_haptics';
  static const _kLang = 'atv_lang';
  static const _kOnboarded = 'atv_onboarded';
  static const _kMouseSens = 'atv_mouse_sens';
  // Legacy single-TV keys (migrated on first load).
  static const _kCertPem = 'atv_cert_pem';
  static const _kKeyPem = 'atv_key_pem';
  static const _kHost = 'atv_host';
  static const _kName = 'atv_name';

  /// Secure store for per-TV credentials (certs, keys, Samsung/LG tokens).
  final SecretStore _secrets = SecretStore();

  /// All TVs we've paired with, most-recently-used first.
  List<PairedTv> pairedTvs = [];

  /// The TV currently being controlled (or pairing with).
  PairedTv? _active;

  /// During first-time pairing we hold the candidate identity here until the
  /// code is confirmed, then promote it into [pairedTvs].
  ClientCertificate? _pendingCert;
  String? _pendingHost;
  String? _pendingName;
  String _pendingDeviceId = '';
  RemoteProtocol _pendingProtocol = RemoteProtocol.googleTv;

  PairingClient? _pairing;
  RemoteBackend? _backend;
  StreamSubscription<RemoteConnectionState>? _backendSub;

  // Auto-reconnect state.
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _disposed = false;
  bool _userDisconnected = false; // suppress auto-retry on manual disconnect

  RemoteConnectionState connection = RemoteConnectionState.disconnected;
  String? lastError;
  bool busy = false;
  AppStage stage = AppStage.discovery;
  bool loading = true;

  /// True while we're waiting for the user to accept an on-screen approval on
  /// a Samsung/LG TV during first-time pairing. Drives a UI hint.
  bool approvalPending = false;

  List<DiscoveredTv> discovered = const [];
  bool scanning = false;

  /// The user's chosen remote layout (persisted). Classic is the default —
  /// the familiar TV-style remote with a circular D-pad and corner keys.
  RemoteLayout layout = RemoteLayout.classic;

  /// Whether haptic feedback is enabled (persisted).
  bool hapticsEnabled = true;

  /// UI language (persisted). Defaults to device locale on first run.
  AppLang lang = AppLang.en;

  /// Whether the user has completed first-run onboarding.
  bool onboarded = false;

  /// App version shown in Settings → About.
  String get appVersion => '1.0.0';

  String? get host => _active?.host ?? _pendingHost;
  String get tvName {
    final n = _active?.name ?? _pendingName;
    if (n != null && n.isNotEmpty) return n;
    final h = host;
    final match = discovered.where((d) => d.host == h);
    if (match.isNotEmpty) return match.first.name;
    return 'TV';
  }

  bool get isConnected => connection == RemoteConnectionState.connected;
  bool get hasPairedTvs => pairedTvs.isNotEmpty;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Loads saved TVs from disk (migrating any legacy single-TV record).
  Future<void> load() async {
    // Keep the splash up long enough for its intro animation to read, but run
    // that minimum concurrently with the real load — so startup is max(load,
    // splash) rather than load + a fixed penalty.
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 700));
    final prefs = await SharedPreferences.getInstance();
    final rawTvs = prefs.getString(_kTvs);

    if (PairedTv.listHasInlineSecrets(rawTvs)) {
      // Upgrade: older builds kept cert/key/token inline in SharedPreferences.
      // Move every secret into the OS keystore, then rewrite the list without
      // them so the plaintext copy is gone after this run.
      final legacy = PairedTv.decodeList(rawTvs, legacy: true);
      for (final tv in legacy) {
        await _secrets.write(tv.id, tv.secrets);
      }
      pairedTvs = legacy.map((t) => t.withSecrets(t.secrets)).toList();
      await _persist();
    } else {
      pairedTvs = PairedTv.decodeList(rawTvs);
      // Rehydrate each TV's credentials from secure storage.
      for (var i = 0; i < pairedTvs.length; i++) {
        final s = await _secrets.read(pairedTvs[i].id);
        if (!s.isEmpty) pairedTvs[i] = pairedTvs[i].withSecrets(s);
      }
    }
    layout = RemoteLayout.values.firstWhere(
      (l) => l.name == prefs.getString(_kLayout),
      orElse: () => RemoteLayout.classic,
    );
    hapticsEnabled = prefs.getBool(_kHaptics) ?? true;
    Haptics.enabled = hapticsEnabled;
    onboarded = prefs.getBool(_kOnboarded) ?? false;
    mouseSensitivity = (prefs.getDouble(_kMouseSens) ?? 1.0).clamp(0.5, 2.0);
    _airMouse = AirMouse(sensitivity: 14.0 * mouseSensitivity);
    final savedLang = prefs.getString(_kLang);
    if (savedLang != null) {
      lang = AppLang.values.firstWhere((l) => l.code == savedLang,
          orElse: () => AppLang.en);
    } else {
      // First run: follow the device language (Arabic if the system is Arabic).
      lang = PlatformDispatcher.instance.locale.languageCode.startsWith('ar')
          ? AppLang.ar
          : AppLang.en;
    }

    // Migrate a legacy single saved pairing into the list.
    if (pairedTvs.isEmpty) {
      final c = prefs.getString(_kCertPem);
      final k = prefs.getString(_kKeyPem);
      final h = prefs.getString(_kHost);
      if (c != null && k != null && h != null) {
        final migrated = PairedTv(
          host: h,
          name: prefs.getString(_kName) ?? 'TV',
          certPem: c,
          keyPem: k,
          lastUsed: _now(),
        );
        await _secrets.write(migrated.id, migrated.secrets);
        pairedTvs = [migrated];
        await _persist();
        await prefs.remove(_kCertPem);
        await prefs.remove(_kKeyPem);
        await prefs.remove(_kHost);
        await prefs.remove(_kName);
      }
    }

    _sortTvs();
    // If we have saved TVs, open straight into the remote for the most recent.
    if (pairedTvs.isNotEmpty) {
      _active = pairedTvs.first;
      stage = AppStage.remote;
    }
    await minSplash;
    loading = false;
    notifyListeners();
  }

  void _sortTvs() =>
      pairedTvs.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    // Metadata only — never write cert/key/token to SharedPreferences.
    await prefs.setString(_kTvs, PairedTv.encodeList(pairedTvs));
    // Secrets go to the OS keystore, keyed per TV.
    for (final tv in pairedTvs) {
      if (!tv.secrets.isEmpty) await _secrets.write(tv.id, tv.secrets);
    }
  }

  void _upsert(PairedTv tv) {
    pairedTvs
        .removeWhere((t) => t.host == tv.host && t.protocol == tv.protocol);
    pairedTvs.insert(0, tv);
    _sortTvs();
  }

  /// Removes the active (or given) TV's pairing.
  Future<void> forget([PairedTv? tv]) async {
    final target = tv ?? _active;
    if (target == null) return;
    final sameActive = _active?.host == target.host &&
        _active?.protocol == target.protocol;
    if (sameActive) _backend?.disconnect();
    pairedTvs.removeWhere(
        (t) => t.host == target.host && t.protocol == target.protocol);
    if (sameActive) _active = null;
    await _secrets.delete(target.id); // wipe credentials from the keystore
    await _persist();
    connection = RemoteConnectionState.disconnected;
    if (_active == null) stage = AppStage.discovery;
    notifyListeners();
  }

  PairedTv? _savedForHostProto(String host, RemoteProtocol protocol) {
    final m = pairedTvs.where((t) => t.host == host && t.protocol == protocol);
    return m.isEmpty ? null : m.first;
  }

  /// Finds a saved TV by stable device id first (survives IP changes), then by
  /// host. [deviceId] may be empty (manual entries / responders with no UUID).
  PairedTv? _savedForDevice(
      String deviceId, String host, RemoteProtocol protocol) {
    if (deviceId.isNotEmpty) {
      final byId = pairedTvs
          .where((t) => t.deviceId == deviceId && t.protocol == protocol);
      if (byId.isNotEmpty) return byId.first;
    }
    return _savedForHostProto(host, protocol);
  }

  // ---------------- Settings ----------------

  /// Toggles haptic feedback and persists it.
  Future<void> setHaptics(bool on) async {
    hapticsEnabled = on;
    Haptics.enabled = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, on);
  }

  /// Changes the UI language and persists it.
  Future<void> setLang(AppLang l) async {
    if (lang == l) return;
    lang = l;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, l.code);
  }

  /// Marks first-run onboarding complete.
  Future<void> completeOnboarding() async {
    onboarded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, true);
  }

  /// Changes the remote layout and persists it.
  Future<void> setLayout(RemoteLayout l) async {
    if (layout == l) return;
    layout = l;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLayout, l.name);
  }

  // ---------------- Discovery ----------------

  Future<void> scan() async {
    scanning = true;
    notifyListeners();
    try {
      discovered = await TvDiscovery.discover();
    } catch (e) {
      lastError = e.toString();
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  // ---------------- Connect-or-pair ----------------

  /// Active TV's protocol (defaults to Google TV).
  RemoteProtocol get activeProtocol =>
      _active?.protocol ?? _pendingProtocol;

  /// Selects a discovered TV. Routes by protocol:
  ///  - CVTE: connect directly over WebSocket (no pairing code).
  ///  - Google TV: try saved cert, else start the pairing-code flow.
  Future<void> connectOrPair(
    String host, {
    String? name,
    RemoteProtocol protocol = RemoteProtocol.googleTv,
    int port = 6466,
    String deviceId = '',
  }) async {
    _setBusy(true);
    lastError = null;
    _userDisconnected = false;
    _retryCount = 0;
    try {
      // Reconnect to a saved TV directly. Match by stable device id first (so a
      // changed IP still finds it), then fall back to host.
      final saved = _savedForDevice(deviceId, host, protocol);
      if (saved != null) {
        // The TV may have moved to a new IP — re-bind the saved record to the
        // address we just discovered it at.
        final rebound =
            saved.host != host ? saved.copyWith(host: host) : saved;
        if (saved.host != host) {
          _upsert(rebound);
          await _persist();
        }
        _active = rebound.copyWith(name: name);
        try {
          await _openControl(rebound);
          _markUsed(rebound);
          stage = AppStage.remote;
          notifyListeners();
          return;
        } catch (e) {
          // Fall through to (re)pair / reconnect.
          atvLog('reconnect saved ${rebound.protocol.name}', e);
        }
      }

      // Every protocol except Google TV connects directly (some prompt the
      // user on the TV the first time, e.g. Samsung/LG).
      if (protocol != RemoteProtocol.googleTv) {
        final tv = PairedTv(
          host: host,
          name: (name?.isNotEmpty ?? false) ? name! : protocol.label,
          protocol: protocol,
          port: port,
          deviceId: deviceId,
          lastUsed: _now(),
        );
        _active = tv;
        // First Samsung/LG connect pops an approval prompt on the TV — tell the
        // user to look at the screen while we wait for them to accept.
        final needsApproval = (protocol == RemoteProtocol.samsung ||
                protocol == RemoteProtocol.lg) &&
            tv.authToken.isEmpty;
        if (needsApproval) {
          approvalPending = true;
          notifyListeners();
        }
        try {
          await _openControl(tv);
        } catch (e) {
          lastError = 'Could not connect to ${protocol.label} at $host. '
              'Make sure it is on and on the same Wi-Fi'
              '${protocol == RemoteProtocol.samsung || protocol == RemoteProtocol.lg ? ', and accept the prompt on the TV' : ''}.';
          notifyListeners();
          rethrow;
        } finally {
          if (approvalPending) {
            approvalPending = false;
            notifyListeners();
          }
        }
        _upsert(tv);
        await _persist();
        stage = AppStage.remote;
        notifyListeners();
        return;
      }

      // Google TV -> pairing-code flow.
      try {
        await _beginPairing(host, name: name, deviceId: deviceId);
      } on PairingException {
        // Distinguish "TV not in pairing mode" from other failures so the UI
        // can tell the user what to do. Probe both ports concurrently so the
        // error path waits ~3s, not ~6s.
        final probes = await Future.wait([
          _isReachable(host, RemoteClient.port),
          _isReachable(host, PairingClient.port),
        ]);
        final controlUp = probes[0];
        final pairUp = probes[1];
        if (controlUp && !pairUp) {
          throw const PairingException(
              'This TV isn\'t ready to pair. On the TV, open '
              'Settings → Remotes & Accessories → Pair accessory, then tap the '
              'TV here again.');
        }
        rethrow;
      }
      stage = AppStage.pairing;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Connects to a CVTE TV given only a PIN code (decodes IP+port from it).
  Future<void> connectCvtePin(String pin) async {
    final decoded = CvtePin.decode(pin);
    if (decoded == null) {
      throw const PairingException('Invalid PIN code');
    }
    final (host, port) = decoded;
    await connectOrPair(host,
        protocol: RemoteProtocol.cvte, port: port, name: 'Smart Board');
  }

  Future<void> openSaved(PairedTv tv) => connectOrPair(
        tv.host,
        name: tv.name,
        protocol: tv.protocol,
        port: tv.port,
        deviceId: tv.deviceId,
      );

  void _markUsed(PairedTv tv) {
    final updated = tv.copyWith(lastUsed: _now());
    _upsert(updated);
    _active = updated;
    _persist();
  }

  // ---------------- Pairing (Google TV only) ----------------

  Future<void> _beginPairing(String host,
      {String? name, String deviceId = ''}) async {
    final saved =
        _savedForDevice(deviceId, host, RemoteProtocol.googleTv);
    _pendingCert = saved?.cert ?? await compute(_generateCert, null);
    _pendingHost = host;
    _pendingName = name ?? saved?.name;
    _pendingDeviceId = deviceId.isNotEmpty ? deviceId : (saved?.deviceId ?? '');
    _pendingProtocol = RemoteProtocol.googleTv;
    _pairing?.dispose();
    _pairing = PairingClient(host: host, cert: _pendingCert!);
    try {
      await _pairing!.start();
    } catch (e) {
      lastError = e.toString();
      _pairing?.dispose();
      _pairing = null;
      rethrow;
    }
  }

  /// Submits the Google TV pairing code. Saves the TV and connects.
  Future<void> submitCode(String code) async {
    if (_pairing == null) throw const PairingException('Pairing not started');
    _setBusy(true);
    lastError = null;
    try {
      await _pairing!.finish(code);
      final tv = PairedTv(
        host: _pendingHost!,
        name: (_pendingName?.isNotEmpty ?? false) ? _pendingName! : 'TV',
        protocol: RemoteProtocol.googleTv,
        port: 6466,
        certPem: _pendingCert!.certificatePem,
        keyPem: _pendingCert!.privateKeyPem,
        deviceId: _pendingDeviceId,
        lastUsed: _now(),
      );
      _upsert(tv);
      _active = tv;
      await _persist();
      _pairing!.dispose();
      _pairing = null;
      await _openControl(tv);
      stage = AppStage.remote;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void cancelPairing() {
    _pairing?.dispose();
    _pairing = null;
    _pendingCert = null;
    _pendingHost = null;
    _pendingName = null;
    stage = _active != null ? AppStage.remote : AppStage.discovery;
    notifyListeners();
  }

  // ---------------- Control ----------------

  /// Reconnect to the active TV; for Google TV, re-pair if reachable.
  Future<void> connect() async {
    final tv = _active;
    if (tv == null) return;
    _userDisconnected = false;
    _setBusy(true);
    try {
      await _openControl(tv);
      _markUsed(tv);
    } catch (e) {
      lastError = e.toString();
      if (tv.protocol == RemoteProtocol.googleTv &&
          await _isReachable(tv.host, RemoteClient.port)) {
        try {
          await _beginPairing(tv.host, name: tv.name);
          stage = AppStage.pairing;
        } catch (_) {/* leave disconnected */}
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> _isReachable(String host, int port) async {
    try {
      final s = await Socket.connect(host, port,
          timeout: const Duration(seconds: 3));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Builds the right backend for [tv]'s protocol and connects.
  Future<void> _openControl(PairedTv tv) async {
    // Tear down any previous backend + its state listener to avoid leaks and
    // stale "disconnected" events from the old socket racing the new one.
    await _backendSub?.cancel();
    _backendSub = null;
    _backend?.dispose();

    // Persists a Samsung token / LG client-key obtained during connect.
    void saveToken(String token) {
      final cur = _savedForHostProto(tv.host, tv.protocol) ?? tv;
      final updated = cur.copyWith(authToken: token);
      _upsert(updated);
      _active = updated;
      _persist();
    }

    final RemoteBackend backend;
    switch (tv.protocol) {
      case RemoteProtocol.cvte:
        backend = CvteBackend(host: tv.host, port: tv.port);
        break;
      case RemoteProtocol.roku:
        backend = RokuBackend(host: tv.host, port: tv.port);
        break;
      case RemoteProtocol.samsung:
        backend = SamsungBackend(
          host: tv.host,
          port: tv.port,
          token: tv.authToken.isEmpty ? null : tv.authToken,
          onToken: saveToken,
        );
        break;
      case RemoteProtocol.lg:
        backend = LgBackend(
          host: tv.host,
          port: tv.port,
          clientKey: tv.authToken.isEmpty ? null : tv.authToken,
          onClientKey: saveToken,
        );
        break;
      case RemoteProtocol.ir:
        backend = IrBackend();
        break;
      case RemoteProtocol.googleTv:
        final ctx = SecurityContext(withTrustedRoots: false);
        ctx.useCertificateChainBytes(_pemBytes(tv.cert.certificatePem));
        ctx.usePrivateKeyBytes(_pemBytes(tv.cert.privateKeyPem));
        backend = GoogleTvBackend(host: tv.host, context: ctx);
        break;
    }
    _backend = backend;
    _backendSub = backend.stateStream.listen((s) {
      connection = s;
      notifyListeners();
      if (s == RemoteConnectionState.disconnected) {
        _onUnexpectedDrop(backend);
      } else if (s == RemoteConnectionState.connected) {
        _retryCount = 0;
        _retryTimer?.cancel();
      }
    });
    await backend.connect();
  }

  /// Schedules an automatic reconnect after an unexpected disconnect, with
  /// capped exponential backoff. No-op if the user navigated away, the drop is
  /// for a stale backend, or we're no longer on the remote screen.
  void _onUnexpectedDrop(RemoteBackend backend) {
    if (_disposed || _userDisconnected) return;
    if (backend != _backend) return; // stale backend event
    if (stage != AppStage.remote) return;
    if (_retryCount >= 5) return; // give up after ~30s of tries
    final delaySec = [2, 4, 8, 15, 30][_retryCount];
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySec), () {
      if (_disposed || _userDisconnected) return;
      if (stage != AppStage.remote) return;
      if (connection == RemoteConnectionState.connected) return;
      connect();
    });
  }

  /// Returns to discovery without unpairing.
  void backToDiscovery() {
    _userDisconnected = true;
    _retryTimer?.cancel();
    _backend?.disconnect();
    stage = AppStage.discovery;
    notifyListeners();
  }

  void sendKey(int keyCode) => _backend?.sendKey(keyCode);
  void launchApp(String uri) => _backend?.launchApp(uri);

  /// Roku-only: the apps installed on the active TV (empty for other backends).
  Future<List<RokuApp>> rokuApps() async {
    final b = _backend;
    if (b is RokuBackend) return b.queryApps();
    return const [];
  }

  /// Host/port of the active Roku (for app icon URLs); null otherwise.
  (String, int)? get rokuTarget {
    final b = _backend;
    if (b is RokuBackend) return (b.host, b.port);
    return null;
  }
  void sendText(String text) => _backend?.sendText(text);
  void backspace() => _backend?.backspace();
  void enter() => _backend?.enter();
  void moveCursor(double dx, double dy) => _moveCursor(dx, dy);
  void click() => _backend?.click();

  // --- Mouse / Air mouse ---
  AirMouse _airMouse = AirMouse();
  bool airMouseActive = false;

  /// Air-mouse sensitivity 0.5–2.0 (persisted). 1.0 = default speed.
  double mouseSensitivity = 1.0;

  // For protocols without a real pointer (Android TV), we accumulate cursor
  // deltas and emit a DPAD step once a threshold is crossed.
  double _accX = 0, _accY = 0;
  DateTime _lastDpad = DateTime.fromMillisecondsSinceEpoch(0);

  /// True when the active protocol has a real on-screen pointer (CVTE, LG).
  bool get hasRealPointer =>
      activeProtocol == RemoteProtocol.cvte ||
      activeProtocol == RemoteProtocol.lg;

  /// Routes a pointer delta: a real cursor move on CVTE, or accumulated into
  /// DPAD steps on protocols without a pointer.
  void _moveCursor(double dx, double dy) {
    if (_backend == null) return;
    if (hasRealPointer) {
      _backend!.moveCursor(dx, dy);
      return;
    }
    // Android TV etc.: convert sustained movement into DPAD presses.
    _accX += dx;
    _accY += dy;
    const threshold = 28.0; // pixels before a step fires
    final now = DateTime.now();
    if (now.difference(_lastDpad).inMilliseconds < 90) return; // rate limit
    if (_accX.abs() < threshold && _accY.abs() < threshold) return;
    if (_accX.abs() > _accY.abs()) {
      _backend!.sendKey(_accX > 0 ? KeyCode.dpadRight : KeyCode.dpadLeft);
    } else {
      _backend!.sendKey(_accY > 0 ? KeyCode.dpadDown : KeyCode.dpadUp);
    }
    _accX = 0;
    _accY = 0;
    _lastDpad = now;
  }

  /// Starts the gyroscope air mouse. Movement routes through [_moveCursor].
  /// Stops voice first — the two shouldn't run at once.
  Future<void> startAirMouse() async {
    if (_backend == null || airMouseActive) return;
    if (voiceActive) await stopVoice();
    _accX = 0;
    _accY = 0;
    // Start the on-screen cursor from the middle (real-pointer backends).
    final b = _backend;
    if (b is CvteBackend) b.recenterCursor();
    airMouseActive = true;
    notifyListeners();
    _airMouse.start(_moveCursor);
  }

  Future<void> stopAirMouse() async {
    if (!airMouseActive) return;
    await _airMouse.stop();
    airMouseActive = false;
    notifyListeners();
  }

  /// Updates air-mouse sensitivity (0.5–2.0) and persists it. Rebuilds the
  /// AirMouse with the new scale (restarting it if currently active).
  Future<void> setMouseSensitivity(double value) async {
    mouseSensitivity = value.clamp(0.5, 2.0);
    final wasActive = airMouseActive;
    if (wasActive) await stopAirMouse();
    _airMouse = AirMouse(sensitivity: 14.0 * mouseSensitivity);
    if (wasActive) await startAirMouse();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMouseSens, mouseSensitivity);
  }

  // --- Voice ---
  bool voiceActive = false;
  final _mic = VoiceMic();

  /// Push-to-talk: opens the TV voice session (KEYCODE_SEARCH -> voice_begin),
  /// then streams the mic until [stopVoice].
  Future<bool> startVoice() async {
    if (_backend == null || voiceActive) return false;
    if (airMouseActive) await stopAirMouse(); // mutually exclusive
    if (!await _mic.ensurePermission()) {
      lastError = 'Microphone permission denied';
      notifyListeners();
      return false;
    }
    voiceActive = true;
    notifyListeners();

    // Match the reference (androidtvremote2 demo): open the voice session
    // FIRST (KEYCODE_SEARCH -> wait for voice_begin -> echo begin), and only
    // then start the mic and stream chunks straight through.
    final ok = await _backend!.startVoice();
    if (!ok) {
      voiceActive = false;
      lastError = 'Voice search not available on this TV';
      notifyListeners();
      return false;
    }
    await _mic.start((pcm) => _backend?.sendVoiceChunk(pcm));
    return true;
  }

  Future<void> stopVoice() async {
    if (!voiceActive) return;
    await _mic.stop();
    _backend?.endVoice();
    voiceActive = false;
    notifyListeners();
  }

  void _setBusy(bool b) {
    busy = b;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _backendSub?.cancel();
    _mic.dispose();
    _airMouse.dispose();
    _pairing?.dispose();
    _backend?.dispose();
    super.dispose();
  }

  static Uint8List _pemBytes(String pem) => Uint8List.fromList(pem.codeUnits);
}

/// Runs on a background isolate — RSA keygen is CPU heavy (~1-3s).
ClientCertificate _generateCert(_) => ClientCertificate.generate();
