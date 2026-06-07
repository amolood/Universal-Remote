import 'dart:convert';
import 'dart:typed_data';

/// Minimal hand-written protobuf wire encoder/decoder.
///
/// Only supports the wire types needed by the Android TV Remote v2 protocol:
/// varint (0), length-delimited (2). This avoids a build-time protoc/codegen
/// dependency while keeping full control over the byte layout.

/// Protobuf wire types.
class WireType {
  static const int varint = 0;
  static const int fixed32 = 5;
  static const int lengthDelimited = 2;
}

/// Builds a protobuf message field by field.
class ProtoWriter {
  final BytesBuilder _b = BytesBuilder();

  /// Tag = (fieldNumber << 3) | wireType
  void _tag(int field, int wireType) => _varint((field << 3) | wireType);

  void _varint(int value) {
    // Protobuf varints are unsigned. Negative ints (int32) are sign-extended
    // to 64 bits; we mask into a 64-bit unsigned representation via BigInt.
    if (value < 0) {
      var v = BigInt.from(value).toUnsigned(64);
      final mask = BigInt.from(0x7f);
      while (v > mask) {
        _b.addByte(((v & mask).toInt()) | 0x80);
        v = v >> 7;
      }
      _b.addByte(v.toInt());
      return;
    }
    var v = value;
    while (v > 0x7f) {
      _b.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _b.addByte(v & 0x7f);
  }

  /// Writes an int32/int64/enum/bool field (varint wire type).
  void writeInt(int field, int value) {
    _tag(field, WireType.varint);
    _varint(value);
  }

  /// Writes a uint32 field (same wire encoding as writeInt for non-negative).
  void writeUint(int field, int value) => writeInt(field, value);

  void writeBool(int field, bool value) => writeInt(field, value ? 1 : 0);

  void writeEnum(int field, int value) => writeInt(field, value);

  /// Writes a length-delimited bytes field.
  void writeBytes(int field, List<int> value) {
    _tag(field, WireType.lengthDelimited);
    _varint(value.length);
    _b.add(value);
  }

  /// Writes a UTF-8 string field.
  void writeString(int field, String value) =>
      writeBytes(field, _utf8(value));

  /// Writes a nested message field.
  void writeMessage(int field, ProtoWriter nested) =>
      writeBytes(field, nested.toBytes());

  /// Writes a 32-bit float field (fixed32 wire type, little-endian).
  void writeFloat(int field, double value) {
    _tag(field, WireType.fixed32);
    final bytes = ByteData(4)..setFloat32(0, value, Endian.little);
    _b.add(bytes.buffer.asUint8List());
  }

  Uint8List toBytes() => _b.toBytes();

  static List<int> _utf8(String s) {
    // Avoid importing dart:convert just for this; but utf8 is fine. Keep simple.
    return s.codeUnits.any((c) => c > 127)
        ? Uint8List.fromList(_encodeUtf8(s))
        : s.codeUnits;
  }

  static List<int> _encodeUtf8(String s) {
    final out = <int>[];
    for (final r in s.runes) {
      if (r < 0x80) {
        out.add(r);
      } else if (r < 0x800) {
        out.add(0xC0 | (r >> 6));
        out.add(0x80 | (r & 0x3F));
      } else if (r < 0x10000) {
        out.add(0xE0 | (r >> 12));
        out.add(0x80 | ((r >> 6) & 0x3F));
        out.add(0x80 | (r & 0x3F));
      } else {
        out.add(0xF0 | (r >> 18));
        out.add(0x80 | ((r >> 12) & 0x3F));
        out.add(0x80 | ((r >> 6) & 0x3F));
        out.add(0x80 | (r & 0x3F));
      }
    }
    return out;
  }
}

/// A single decoded protobuf field.
class ProtoField {
  final int number;
  final int wireType;
  final int? varint; // for wire type 0
  final Uint8List? bytes; // for wire type 2
  final Uint8List? rawFixed32; // for wire type 5

  ProtoField(this.number, this.wireType,
      {this.varint, this.bytes, this.rawFixed32});
}

/// Reads protobuf fields sequentially from a buffer.
class ProtoReader {
  final Uint8List _data;
  int _pos = 0;

  ProtoReader(this._data);

  bool get hasMore => _pos < _data.length;

  int _readVarint() {
    // Protobuf varints are up to 10 bytes (64 bits). Dart's native `int` is a
    // 64-bit two's-complement value, so shifting a byte's 7 payload bits into
    // place fills the full width correctly — but only while `shift < 64`. Past
    // that the high group bits are overflow padding (0x01 for an int64) and
    // contribute nothing, so we read them to advance `_pos` but don't shift.
    int result = 0;
    int shift = 0;
    while (true) {
      if (_pos >= _data.length) {
        throw const FormatException('Truncated varint');
      }
      final b = _data[_pos++];
      if (shift < 64) {
        result |= (b & 0x7f) << shift;
      }
      if ((b & 0x80) == 0) break;
      shift += 7;
      if (shift > 70) {
        // More than 10 bytes — malformed; bail rather than loop forever.
        throw const FormatException('Varint too long');
      }
    }
    return result;
  }

  ProtoField readField() {
    final tag = _readVarint();
    final field = tag >> 3;
    final wireType = tag & 0x7;
    switch (wireType) {
      case WireType.varint:
        return ProtoField(field, wireType, varint: _readVarint());
      case WireType.lengthDelimited:
        final len = _readVarint();
        final b = _data.sublist(_pos, _pos + len);
        _pos += len;
        return ProtoField(field, wireType, bytes: b);
      case 5: // fixed32 — capture 4 bytes
        final f32 = _data.sublist(_pos, _pos + 4);
        _pos += 4;
        return ProtoField(field, wireType, rawFixed32: f32);
      case 1: // fixed64 — skip 8 bytes
        _pos += 8;
        return ProtoField(field, wireType);
      default:
        throw FormatException('Unsupported wire type $wireType');
    }
  }

  /// Reads all top-level fields into a map keyed by field number.
  /// Repeated fields are collapsed (last wins) except where caller handles.
  Map<int, ProtoField> readAll() {
    final map = <int, ProtoField>{};
    while (hasMore) {
      final f = readField();
      map[f.number] = f;
    }
    return map;
  }
}

/// Decodes a UTF-8 string from bytes. Tolerates malformed/truncated sequences
/// (which can occur at a socket-buffer boundary) by emitting U+FFFD rather than
/// throwing a RangeError, so a single bad frame can't take down the connection.
String decodeUtf8(List<int> bytes) =>
    const Utf8Decoder(allowMalformed: true).convert(bytes);
