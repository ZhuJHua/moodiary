import 'dart:async';

import 'video_playback_state.dart';

class VideoPortSnapshot {
  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;

  final int width;
  final int height;

  final int rotationDegrees;

  final String? errorMessage;

  const VideoPortSnapshot({
    required this.isInitialized,
    required this.isPlaying,
    required this.isBuffering,
    required this.isCompleted,
    required this.position,
    required this.duration,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.errorMessage,
  });

  double? get displayAspect {
    if (width <= 0 || height <= 0) return null;
    final swap = rotationDegrees % 180 == 90;
    final w = swap ? height : width;
    final h = swap ? width : height;
    return w / h;
  }

  static const empty = VideoPortSnapshot(
    isInitialized: false,
    isPlaying: false,
    isBuffering: false,
    isCompleted: false,
    position: .zero,
    duration: .zero,
    width: 0,
    height: 0,
    rotationDegrees: 0,
    errorMessage: null,
  );
}

abstract class VideoPlaybackPort {
  Stream<VideoPortSnapshot> get snapshots;

  VideoPortSnapshot get snapshot;

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setPlaybackSpeed(double speed);

  Future<void> setLooping(bool looping);

  Future<void> dispose();
}

typedef VideoPlaybackPortFactory = VideoPlaybackPort Function(
  VideoSource source,
);
