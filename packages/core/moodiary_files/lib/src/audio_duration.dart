import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

Future<Duration?> probeAudioDuration(String path) {
  return Isolate.run(() {
    try {
      final duration = readMetadata(File(path)).duration;
      if (duration == null || duration <= Duration.zero) return null;
      return duration;
    } catch (_) {
      return null;
    }
  });
}
