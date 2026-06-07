import 'dart:typed_data';

/// The Android TV Remote v2 wire protocol prefixes every protobuf message with
/// its length encoded as a base-128 varint (almost always a single byte, since
/// messages are small). This class accumulates incoming socket bytes and emits
/// complete message payloads.
class MessageFramer {
  final List<int> _buf = [];

  /// Feed raw bytes from the socket; returns any complete message payloads
  /// (without the length prefix) that are now available.
  List<Uint8List> addBytes(List<int> data) {
    _buf.addAll(data);
    final out = <Uint8List>[];
    while (true) {
      final framed = _tryRead();
      if (framed == null) break;
      out.add(framed);
    }
    return out;
  }

  Uint8List? _tryRead() {
    if (_buf.isEmpty) return null;
    // Decode a varint length prefix.
    int length = 0;
    int shift = 0;
    int i = 0;
    while (true) {
      if (i >= _buf.length) return null; // need more bytes for the prefix
      final b = _buf[i];
      length |= (b & 0x7f) << shift;
      i++;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    final prefixLen = i;
    if (_buf.length - prefixLen < length) return null; // body incomplete
    final payload =
        Uint8List.fromList(_buf.sublist(prefixLen, prefixLen + length));
    _buf.removeRange(0, prefixLen + length);
    return payload;
  }
}

/// Prepends a varint length prefix to a payload, producing a wire frame.
Uint8List frame(Uint8List payload) {
  final prefix = <int>[];
  int len = payload.length;
  while (len > 0x7f) {
    prefix.add((len & 0x7f) | 0x80);
    len >>= 7;
  }
  prefix.add(len & 0x7f);
  final out = Uint8List(prefix.length + payload.length);
  out.setRange(0, prefix.length, prefix);
  out.setRange(prefix.length, out.length, payload);
  return out;
}
