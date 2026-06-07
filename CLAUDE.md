# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`atv_remote` (package `com.molood.atv_remote`) — a Flutter phone app that discovers, pairs with, and controls TVs/streaming devices on the local network (Android TV/Google TV, CVTE/Bytello boards, Roku, Samsung, LG) plus IR-blaster control. No cloud, no backend, no companion hardware; all control traffic stays on the LAN. Also controls IR/Wi-Fi appliances (air conditioners). English + Arabic with full RTL.

## Commands

```bash
flutter pub get                                   # install deps
flutter run                                        # run on a connected device
flutter test                                       # all unit tests
flutter test test/protobuf_test.dart               # single test file
flutter test --plain-name "maps digits to Lit_"    # single test by name
flutter analyze                                     # static analysis (flutter_lints)
flutter build apk --release --split-per-abi        # per-ABI release APKs
```

Live integration against a real TV (not part of `flutter test`):

```bash
dart run tool/live_pair.dart <host> [savedCertDir]  # full pair+control flow; reads PIN from /tmp/atv_pin
dart run tool/probe_control.dart                     # probe control connection
dart run tool/probe_voice.dart                       # probe voice session
```

## Architecture

**State management is two `ChangeNotifier` controllers** provided at the root via `provider` (see [lib/main.dart](lib/main.dart)):

- `AtvController` ([lib/atv/atv_controller.dart](lib/atv/atv_controller.dart)) — owns saved TVs, the active pairing session, the live backend, discovery, air-mouse, and voice. This is the hub; almost all TV state lives here.
- `ApplianceController` ([lib/appliances/appliance_controller.dart](lib/appliances/appliance_controller.dart)) — mirrors `AtvController`'s shape for IR/Wi-Fi appliances. Supports all `ApplianceKind`s: air conditioner, fan, TV, light, radio, DVD, set-top box, projector, soundbar, heater, generic. `ApplianceKind.isKeyBased` splits them: **state-based** kinds (AC, fan, light, heater) carry a per-kind state model (`AcState`/`FanState`/`LightState`/`HeaterState`) applied via `applyAc`/`applyFan`/`applyLight`/`applyHeater`; **key-based** kinds (TV, radio, DVD, STB, projector, soundbar, generic) send momentary `DeviceKey`s via `sendDeviceKey`. AC IR uses stateful brand frames ([ac_ir_encoder.dart](lib/appliances/ac_ir_encoder.dart)); every other kind uses generic key-based **NEC** encoders ([device_ir_encoder.dart](lib/appliances/device_ir_encoder.dart)), one per kind, with `DeviceKey` covering nav, digits 0-9, and media-transport keys. For IR state-based kinds, the `apply*` methods diff against the previous state and emit the matching step presses (speed/brightness/level ±, oscillate toggle) since the remote is key-based, not stateful. UI panels are tailored per kind in [appliances_screen.dart](lib/ui/appliances_screen.dart) (`_panelFor`), reusing shared `DpadControl`/`KeypadControl`/`KeyStepper` widgets. **Brands** come from [brand_catalog.dart](lib/appliances/brand_catalog.dart): an appliance stores a catalog brand id (e.g. `lg`), and the controller's `_acEncoderFor`/`_deviceEncoderFor` resolve `(brand, kind)` → a generic IR encoder via `BrandCatalog.irEncoderId` (falling back to treating `brand` as a direct encoder id for legacy appliances). The catalog maps each brand to the kinds it makes and, per kind, whether it's IR-controllable or **Wi-Fi/smart only** (large kitchen/laundry appliances — Miele, Sub-Zero, etc. — have no IR remote, so the add-flow hides the IR transports for them). IR codes are **generic per kind**, not verified per brand.

The root widget (`_Root` in main.dart) switches between Splash → Onboarding → Remote/Pairing screens off `AtvController.{loading, onboarded, stage}` (`AppStage` enum).

**The protocol abstraction is the key design point.** Every vendor protocol implements one interface, `RemoteBackend` ([lib/atv/backend.dart](lib/atv/backend.dart)), so the UI and controller **never branch on protocol** — they call `sendKey`/`sendText`/`moveCursor`/etc. uniformly. Backends: `googletv_backend`, `cvte_backend`, `roku_backend`, `samsung_backend`, `lg_backend`, `ir_backend`. `RemoteProtocol` (the enum) carries each protocol's `label` and `defaultPort`. `AtvController._openControl()` is the single place that constructs the right backend for a `PairedTv.protocol` and wires up its `stateStream`.

Backends expose state via `Stream<RemoteConnectionState>` (`disconnected/connecting/connected`). `AtvController` listens and auto-reconnects on unexpected drops with capped exponential backoff (`[2,4,8,15,30]s`, see `_onUnexpectedDrop`), suppressed on manual disconnect.

**Protocol-specific notes** (matters when touching a backend):

- **Google TV** is the only protocol with a pairing-code flow (`PairingClient`, port 6467) separate from control (`RemoteClient`, port 6466). It generates a 2048-bit RSA client cert on a **background isolate** via `compute(_generateCert)` (keygen is 1–3s) and presents it over TLS. Has no real pointer — air-mouse deltas are accumulated into DPAD steps in `_moveCursor`.
- **CVTE, LG** have a real on-screen pointer (`hasRealPointer`); cursor moves pass straight through.
- **Samsung/LG** prompt for on-screen approval on first connect and return a token/client-key, persisted via the `onToken`/`onClientKey` callback (`saveToken` in `_openControl`). `approvalPending` drives a UI hint.
- **Roku** needs no pairing; also exposes installed apps (`rokuApps()`/`rokuTarget` only work when the active backend is `RokuBackend`).
- **IR** is networkless — goes through a native `MethodChannel('com.molood.atv_remote/ir')` to `MainActivity.kt`.

**Protobuf is hand-written, no codegen.** [lib/proto/protobuf.dart](lib/proto/protobuf.dart) implements only varint + length-delimited wire types — enough for Android TV Remote v2. There is no protoc dependency; edit the codec directly. Message construction lives in `lib/atv/messages.dart`, length-prefix framing in `lib/atv/framing.dart`.

**Discovery** ([lib/atv/discovery.dart](lib/atv/discovery.dart)) sweeps mDNS (`_androidtvremote2._tcp` for Google TV, `_share._tcp` for CVTE) and SSDP concurrently, de-duped by `(protocol, host)`.

**Stable device identity:** a paired TV is matched by a stable `deviceId` (SSDP UUID / mDNS instance name / serial) **before** host, so it's still recognised after its IP changes (`_savedForDevice`). When found at a new IP, the saved record is re-bound to the new host.

## Security / storage convention

**Secrets never go in SharedPreferences.** Per-TV credentials (Google TV cert+key, Samsung token, LG client-key, appliance secrets) live in the OS keystore via `flutter_secure_storage`, wrapped by `SecretStore` ([lib/atv/secret_store.dart](lib/atv/secret_store.dart)), keyed by a stable id. Only non-sensitive metadata (name, host, protocol) is persisted to prefs via `PairedTv.encodeList` / `Appliance.encodeList`. `AtvController.load()` contains a one-time migration that moves any inline-secret legacy records into the keystore — preserve this when changing the storage format.

## UI

`lib/ui/` holds screens; `lib/ui/widgets/` has the reusable glass-style component set (`glass.dart`, `aurora_background.dart`, `touchpad.dart`). Theme + `Haptics` in `lib/ui/theme.dart`. Strings + `AppLang`/`Localized` (RTL) in [lib/i18n/strings.dart](lib/i18n/strings.dart) — add new user-facing strings there for both `en` and `ar`.

## Testing conventions

Tests cover pure logic: protocol encoders, key mappings (`KeyCode` → per-vendor names, e.g. `RokuBackend.rokuKeyFor`), the protobuf codec, framing, pairing-secret derivation, cert generation, AC IR encoding, and the air-mouse/cursor math. They do **not** hit the network — keep new backend logic that needs testing (key maps, encoders) in pure static/testable functions, as the existing backends do.
