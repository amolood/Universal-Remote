<p align="center">
  <img src="docs/assets/logo.png" alt="Universal Remote" width="120" />
</p>

<h1 align="center">Universal Remote</h1>

<p align="center">
  A phone-based universal TV remote built with Flutter. Discover, pair, and control
  TVs and streaming devices on your local network — Android TV / Google TV, CVTE smart
  boards, Roku, Samsung, and LG — plus infrared control for any TV with an IR blaster.
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white" alt="Dart" /></a>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-555" alt="Platform" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
  <a href="https://pub.dev/packages/flutter_lints"><img src="https://img.shields.io/badge/style-flutter__lints-40C4FF" alt="Style" /></a>
  <img src="https://img.shields.io/badge/tests-54%20passing-brightgreen" alt="Tests" />
</p>

---

## Overview

Universal Remote replaces the physical remotes for the screens around you. It speaks
each vendor's native control protocol directly over the local network, so there is no
cloud account, no companion hub, and no extra hardware — your phone and the TV on the
same Wi-Fi is all that is required. Where a network protocol is unavailable, the app
falls back to infrared through the device's IR emitter.

## Features

- Automatic discovery of devices on the local network (mDNS and SSDP).
- Pairing flows for each protocol, including on-screen code and approval prompts.
- Full directional pad, media transport, volume, and channel controls.
- Touchpad and air-mouse modes, with gyroscope pointer control and adjustable sensitivity.
- On-screen keyboard and number pad for text entry and direct channel input.
- Push-to-talk voice search on protocols that support it.
- Roku app launcher: browse and open the apps installed on the connected device.
- Manual connection by IP address with brand selection when discovery is unavailable.
- Multiple remote layouts: balanced, minimal, touchpad, and classic.
- English and Arabic interface with full right-to-left support.

## Screenshots

<p align="center">
  <img src="docs/screenshots/discovery.png" alt="Device discovery" width="220" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/remote.png" alt="Remote control" width="220" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/settings.png" alt="Settings and layouts" width="220" />
</p>

## Supported devices

| Brand / platform        | Protocol                  | Transport                    | Pairing             |
|-------------------------|---------------------------|------------------------------|---------------------|
| Android TV / Google TV  | Android TV Remote v2      | TLS + protobuf (port 6466)   | On-screen code      |
| CVTE / Bytello boards   | Bytello control           | WebSocket (port 8125)        | PIN                 |
| Roku                    | External Control Protocol | HTTP (port 8060)             | None required       |
| Samsung (Tizen)         | Samsung remote control v2 | Secure WebSocket (port 8002) | On-screen approval  |
| LG (webOS)              | SSAP                      | WebSocket (port 3000)        | On-screen approval  |
| Any TV with IR          | NEC infrared              | Device IR emitter            | None required       |

## Architecture

Each vendor protocol is implemented behind a single `RemoteBackend` interface, so the
interface layer is decoupled from the wire format. A central controller owns the active
backend, exposes a uniform set of commands, and notifies the UI of connection state.

```
lib/
  atv/                   Control backends and networking
    backend.dart           RemoteBackend interface and protocol enum
    atv_controller.dart    App state, backend lifecycle, command routing
    discovery.dart         mDNS and SSDP device discovery
    pairing_secret.dart    Android TV pairing handshake and secret derivation
    googletv_backend.dart
    cvte_backend.dart
    roku_backend.dart
    samsung_backend.dart
    lg_backend.dart
    ir_backend.dart        Native infrared via platform channel
    air_mouse.dart         Gyroscope-to-pointer conversion
  proto/                 Hand-written protobuf wire codec (no codegen)
  i18n/                  English and Arabic strings, RTL handling
  ui/                    Screens, layouts, and reusable widgets
```

Key design points:

- The interface is built with Provider for state management and a custom glass-style
  component set.
- The Android TV handshake generates a 2048-bit RSA client certificate on a background
  isolate and derives the pairing secret from both certificates and the on-screen code.
- The protobuf wire format is hand-written with varint framing, so there is no protoc
  or code-generation dependency.
- Discovery, pairing, and command handling are fully asynchronous and fail soft — a
  dropped packet or an unreachable device never crashes the session.

## Getting started

### Prerequisites

- Flutter 3.41 or newer
- Dart 3.11 or newer
- Android SDK, and Xcode for iOS builds

### Install and run

```bash
flutter pub get
flutter run
```

### Build a release APK

```bash
flutter build apk --release --split-per-abi
```

Split builds produce per-architecture APKs in `build/app/outputs/flutter-apk/`.

## Testing

The protocol encoders, key mappings, pairing logic, and certificate generation are
covered by unit tests:

```bash
flutter test
```

Static analysis uses the `flutter_lints` rule set:

```bash
flutter analyze
```

## Permissions

The app requests only what each feature needs:

- Local network access for discovery and control.
- Microphone access for voice search, requested only when the feature is used.
- `TRANSMIT_IR` for infrared control on devices with an IR emitter.

No data leaves the device; all control traffic stays on the local network.

## Security and privacy

- Per-TV credentials — Google TV client certificates, and the Samsung token and
  LG client-key — are stored in the OS keystore (Android Keystore / iOS Keychain)
  via `flutter_secure_storage`, never in plaintext preferences.
- Only non-sensitive metadata (name, address, protocol) is kept in shared
  preferences; secrets live in secure storage keyed by a stable device id.
- A paired TV is remembered by a stable device identity (SSDP UUID, mDNS service
  name, or serial), so it is still recognised after its IP address changes on the
  network — no need to pair again.
- All control traffic is local; the app has no backend and collects no telemetry.

## Project information

- Package name: `com.molood.atv_remote`
- Minimum Flutter SDK: 3.41

## License

Released under the MIT License. See [LICENSE](LICENSE) for details.
