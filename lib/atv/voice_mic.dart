import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures microphone audio as raw 16-bit PCM, 8kHz, mono — exactly the
/// format the Android TV voice protocol expects — and pushes chunks to a sink.
class VoiceMic {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  Future<bool> ensurePermission() => _recorder.hasPermission();

  /// Starts streaming PCM chunks to [onChunk] until [stop].
  Future<void> start(void Function(Uint8List pcm) onChunk) async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 8000,
        numChannels: 1,
        // Effects off: on some chipsets they can yield silence or distortion.
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      ),
    );
    _sub = stream.listen(onChunk);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
