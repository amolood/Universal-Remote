/// Android RemoteKeyCode values (subset used by the remote UI).
/// Values match the KEYCODE_* constants in remotemessage.proto / Android.
class KeyCode {
  static const int dpadUp = 19;
  static const int dpadDown = 20;
  static const int dpadLeft = 21;
  static const int dpadRight = 22;
  static const int dpadCenter = 23; // OK / select

  static const int home = 3;
  static const int back = 4;
  static const int power = 26;
  static const int menu = 82;
  static const int search = 84;
  static const int assist = 219;

  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int mute = 91;
  static const int volumeMute = 164; // KEYCODE_VOLUME_MUTE

  static const int mediaPlayPause = 85;
  static const int mediaPlay = 126;
  static const int mediaPause = 127;
  static const int mediaStop = 86;
  static const int mediaNext = 87;
  static const int mediaPrevious = 88;
  static const int mediaRewind = 89;
  static const int mediaFastForward = 90;

  static const int channelUp = 166;
  static const int channelDown = 167;

  static const int input = 178; // KEYCODE_TV_INPUT (source)
  static const int settings = 176; // KEYCODE_SETTINGS
  static const int guide = 172; // KEYCODE_GUIDE
  static const int info = 165; // KEYCODE_INFO
  static const int captions = 175; // KEYCODE_CAPTIONS (used for "exit"-like)

  /// Digit 0-9 -> KEYCODE_0 (7) .. KEYCODE_9 (16)
  static int digit(int n) => 7 + n;
}

/// Maps a single character to an Android keycode for text entry.
/// Covers a-z, 0-9, space, and common punctuation reachable via keycodes.
/// Returns null for characters with no direct keycode (callers can skip them).
int? keyCodeForChar(String ch) {
  if (ch.isEmpty) return null;
  final c = ch.toLowerCase();
  final code = c.codeUnitAt(0);
  // a-z -> KEYCODE_A (29) .. KEYCODE_Z (54)
  if (code >= 0x61 && code <= 0x7a) return 29 + (code - 0x61);
  // 0-9 -> KEYCODE_0 (7) .. KEYCODE_9 (16)
  if (code >= 0x30 && code <= 0x39) return 7 + (code - 0x30);
  switch (ch) {
    case ' ':
      return 62; // KEYCODE_SPACE
    case '.':
      return 56; // KEYCODE_PERIOD
    case ',':
      return 55; // KEYCODE_COMMA
    case '@':
      return 77; // KEYCODE_AT
    case '-':
      return 69; // KEYCODE_MINUS
    case '+':
      return 81; // KEYCODE_PLUS
    case '/':
      return 76; // KEYCODE_SLASH
    default:
      return null;
  }
}

/// KEYCODE_DEL (backspace).
const int keyCodeDelete = 67;
const int keyCodeEnter = 66; // KEYCODE_ENTER

/// RemoteDirection enum.
class KeyDirection {
  static const int unknown = 0;
  static const int startLong = 1;
  static const int endLong = 2;
  static const int short = 3;
}

/// Deep-link URIs for launching apps via RemoteAppLinkLaunchRequest.
class AppLink {
  final String name;
  final String uri;
  final String iconAsset; // optional
  const AppLink(this.name, this.uri, {this.iconAsset = ''});

  static const List<AppLink> defaults = [
    AppLink('YouTube', 'https://www.youtube.com'),
    AppLink('Netflix', 'https://www.netflix.com/title'),
    AppLink('Prime Video', 'https://app.primevideo.com'),
    AppLink('Spotify', 'spotify://'),
    AppLink('Play Store', 'market://'),
  ];
}
