import 'dart:typed_data';

import '../proto/protobuf.dart';

// ============================ Pairing (polo.proto) ============================
//
// OuterMessage {
//   required uint32 protocol_version = 1 [default = 1];
//   required Status status = 2;          // 200 = OK
//   optional PairingRequest pairing_request = 10;
//   optional PairingRequestAck pairing_request_ack = 11;
//   optional Options options = 20;
//   optional Configuration configuration = 30;
//   optional ConfigurationAck configuration_ack = 31;
//   optional Secret secret = 40;
//   optional SecretAck secret_ack = 41;
// }

class PairingStatus {
  static const int ok = 200;
  static const int error = 400;
  static const int badConfiguration = 401;
  static const int badSecret = 402;
}

class PairingMessages {
  /// OuterMessage + PairingRequest{ service_name=1, client_name=2 }
  static Uint8List pairingRequest({
    required String serviceName,
    required String clientName,
  }) {
    final req = ProtoWriter()
      ..writeString(1, serviceName)
      ..writeString(2, clientName);
    return _outer(10, req);
  }

  /// OuterMessage + Options:
  ///   Options {
  ///     repeated Encoding input_encodings = 1;
  ///     optional RoleType preferred_role = 3;   // 1 = INPUT
  ///   }
  ///   Encoding { type=1 (HEXADECIMAL=3), symbol_length=2 (6) }
  /// Matches the reference client, which sets only input_encodings and
  /// preferred_role (no output_encodings).
  static Uint8List optionsHex() {
    final encoding = ProtoWriter()
      ..writeEnum(1, 3) // ENCODING_TYPE_HEXADECIMAL
      ..writeUint(2, 6); // symbol_length
    final options = ProtoWriter()
      ..writeEnum(3, 1) // preferred_role = ROLE_TYPE_INPUT
      ..writeMessage(1, encoding); // input_encodings
    return _outer(20, options);
  }

  /// OuterMessage + Configuration:
  ///   Configuration { encoding=1 (Encoding), client_role=2 (RoleType) }
  static Uint8List configuration() {
    final encoding = ProtoWriter()
      ..writeEnum(1, 3) // HEXADECIMAL
      ..writeUint(2, 6);
    final config = ProtoWriter()
      ..writeMessage(1, encoding)
      ..writeEnum(2, 1); // client_role = INPUT
    return _outer(30, config);
  }

  /// OuterMessage + Secret{ secret=1 bytes }
  static Uint8List secret(Uint8List secretBytes) {
    final s = ProtoWriter()..writeBytes(1, secretBytes);
    return _outer(40, s);
  }

  static Uint8List _outer(int field, ProtoWriter payload) {
    final outer = ProtoWriter()
      ..writeUint(1, 2) // protocol_version (reference uses 2)
      ..writeEnum(2, PairingStatus.ok) // status
      ..writeMessage(field, payload);
    return outer.toBytes();
  }
}

/// Parsed view of an incoming pairing OuterMessage.
class PairingResponse {
  final int status;
  final bool hasRequestAck;
  final bool hasOptions;
  final bool hasConfigurationAck;
  final bool hasSecretAck;

  PairingResponse({
    required this.status,
    required this.hasRequestAck,
    required this.hasOptions,
    required this.hasConfigurationAck,
    required this.hasSecretAck,
  });

  bool get ok => status == PairingStatus.ok;

  static PairingResponse parse(Uint8List bytes) {
    final fields = ProtoReader(bytes).readAll();
    return PairingResponse(
      status: fields[2]?.varint ?? PairingStatus.error,
      hasRequestAck: fields.containsKey(11),
      hasOptions: fields.containsKey(20),
      hasConfigurationAck: fields.containsKey(31),
      hasSecretAck: fields.containsKey(41),
    );
  }
}

// ========================= Remote (remotemessage.proto) =======================
//
// RemoteMessage {
//   RemoteConfigure remote_configure = 1;
//   RemoteSetActive remote_set_active = 2;
//   RemoteError remote_error = 3;
//   RemotePingRequest remote_ping_request = 8;
//   RemotePingResponse remote_ping_response = 9;
//   RemoteKeyInject remote_key_inject = 10;
//   RemoteImeKeyInject remote_ime_key_inject = 20;
//   RemoteImeBatchEdit remote_ime_batch_edit = 21;
//   RemoteSetVolumeLevel remote_set_volume_level = 50;
//   RemoteAppLinkLaunchRequest remote_app_link_launch_request = 90;
// }

class RemoteMessages {
  /// The feature bitmask we advertise (matches the reference client):
  /// PING(2) | KEY(4) | VOICE(8) | POWER(32) | VOLUME(64) | APP_LINK(512) = 622.
  static const int activeFeatures = 2 | 4 | 8 | 32 | 64 | 512; // 622

  /// remote_configure (1):
  ///   RemoteConfigure { code1=1, device_info=2 RemoteDeviceInfo }
  ///   RemoteDeviceInfo { model=1, vendor=2, unknown1=3, unknown2=4,
  ///                      package_name=5, app_version=6 }
  ///
  /// Important: the reply must set code1 to the feature bitmask and fill ONLY
  /// unknown1/unknown2/package_name/app_version (no model/vendor) — exactly
  /// like the reference client, or the TV rejects it with remote_error and
  /// closes the socket.
  static Uint8List configure() {
    final deviceInfo = ProtoWriter()
      ..writeInt(3, 1) // unknown1
      ..writeString(4, '1') // unknown2
      ..writeString(5, 'atvremote') // package_name
      ..writeString(6, '1.0.0'); // app_version
    final configure = ProtoWriter()
      ..writeInt(1, activeFeatures)
      ..writeMessage(2, deviceInfo);
    final msg = ProtoWriter()..writeMessage(1, configure);
    return msg.toBytes();
  }

  /// remote_set_active (2): RemoteSetActive { active=1 }
  static Uint8List setActive(int active) {
    final sa = ProtoWriter()..writeInt(1, active);
    final msg = ProtoWriter()..writeMessage(2, sa);
    return msg.toBytes();
  }

  /// remote_ping_response (9): RemotePingResponse { val1=1 }
  static Uint8List pingResponse(int val1) {
    final pr = ProtoWriter()..writeInt(1, val1);
    final msg = ProtoWriter()..writeMessage(9, pr);
    return msg.toBytes();
  }

  /// remote_key_inject (10):
  ///   RemoteKeyInject { key_code=1 (RemoteKeyCode), direction=2 (RemoteDirection) }
  static Uint8List keyInject({required int keyCode, required int direction}) {
    final ki = ProtoWriter()
      ..writeEnum(1, keyCode)
      ..writeEnum(2, direction);
    final msg = ProtoWriter()..writeMessage(10, ki);
    return msg.toBytes();
  }

  /// remote_app_link_launch_request (90):
  ///   RemoteAppLinkLaunchRequest { app_link=1 }
  static Uint8List appLink(String uri) {
    final al = ProtoWriter()..writeString(1, uri);
    final msg = ProtoWriter()..writeMessage(90, al);
    return msg.toBytes();
  }

  /// remote_voice_begin (30): RemoteVoiceBegin { session_id=1 }
  static Uint8List voiceBegin(int sessionId) {
    final vb = ProtoWriter()..writeInt(1, sessionId);
    final msg = ProtoWriter()..writeMessage(30, vb);
    return msg.toBytes();
  }

  /// remote_voice_payload (31): RemoteVoicePayload { session_id=1, samples=2 }
  static Uint8List voicePayload(int sessionId, List<int> samples) {
    final vp = ProtoWriter()
      ..writeInt(1, sessionId)
      ..writeBytes(2, samples);
    final msg = ProtoWriter()..writeMessage(31, vp);
    return msg.toBytes();
  }

  /// remote_voice_end (32): RemoteVoiceEnd { session_id=1 }
  static Uint8List voiceEnd(int sessionId) {
    final ve = ProtoWriter()..writeInt(1, sessionId);
    final msg = ProtoWriter()..writeMessage(32, ve);
    return msg.toBytes();
  }
}

/// Identifies which top-level field an incoming remote message carries,
/// so the client can react (ping -> pong, configure -> set_active, etc.).
class RemoteIncoming {
  final int field; // top-level field number present
  final int? pingVal; // val1 of ping request, if any
  final int? voiceSessionId; // session_id of remote_voice_begin (field 30)

  RemoteIncoming(this.field, {this.pingVal, this.voiceSessionId});

  static RemoteIncoming parse(Uint8List bytes) {
    final reader = ProtoReader(bytes);
    int field = 0;
    int? pingVal;
    int? voiceSessionId;
    while (reader.hasMore) {
      final f = reader.readField();
      field = f.number;
      if (f.number == 8 && f.bytes != null) {
        // remote_ping_request { val1 = 1 }
        final inner = ProtoReader(f.bytes!).readAll();
        pingVal = inner[1]?.varint ?? 1;
      } else if (f.number == 30 && f.bytes != null) {
        // remote_voice_begin { session_id = 1 }
        final inner = ProtoReader(f.bytes!).readAll();
        voiceSessionId = inner[1]?.varint ?? 0;
      }
    }
    return RemoteIncoming(field, pingVal: pingVal, voiceSessionId: voiceSessionId);
  }
}
