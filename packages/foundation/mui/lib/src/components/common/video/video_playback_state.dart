sealed class VideoSource {
  const VideoSource();

  const factory VideoSource.file(String path) = VideoFileSource;
}

class VideoFileSource extends VideoSource {
  final String path;

  const VideoFileSource(this.path);
}

sealed class VideoPlaybackState {
  const VideoPlaybackState();

  bool get isPlayIntent => switch (this) {
    VideoPlaying() => true,
    VideoBuffering(:final resumeIntent) => resumeIntent,
    VideoSeeking(:final resumeIntent) => resumeIntent,
    _ => false,
  };

  bool get isInitialized => switch (this) {
    VideoReady() ||
    VideoPlaying() ||
    VideoBuffering() ||
    VideoPaused() ||
    VideoSeeking() ||
    VideoCompleted() => true,
    _ => false,
  };

  bool get acceptsCommands => isInitialized;

  bool get isBusy => this is VideoInitializing || this is VideoBuffering;
}

class VideoIdle extends VideoPlaybackState {
  const VideoIdle();
}

class VideoInitializing extends VideoPlaybackState {
  final int attempt;

  const VideoInitializing({required this.attempt});
}

class VideoReady extends VideoPlaybackState {
  const VideoReady();
}

class VideoPlaying extends VideoPlaybackState {
  const VideoPlaying();
}

class VideoBuffering extends VideoPlaybackState {
  final bool resumeIntent;

  const VideoBuffering({required this.resumeIntent});
}

class VideoPaused extends VideoPlaybackState {
  const VideoPaused();
}

class VideoSeeking extends VideoPlaybackState {
  final Duration target;
  final bool resumeIntent;

  final bool scrubbing;

  const VideoSeeking({
    required this.target,
    required this.resumeIntent,
    required this.scrubbing,
  });
}

class VideoCompleted extends VideoPlaybackState {
  const VideoCompleted();
}

enum VideoErrorKind { initialize, playback }

class VideoError extends VideoPlaybackState {
  final VideoErrorKind kind;

  final String message;

  final Duration resumeFrom;

  final bool canRetry;
  final int attempt;

  const VideoError({
    required this.kind,
    required this.message,
    required this.resumeFrom,
    required this.canRetry,
    required this.attempt,
  });
}

class VideoDisposed extends VideoPlaybackState {
  const VideoDisposed();
}

class VideoProgress {
  final Duration position;
  final Duration duration;

  final bool draft;

  const VideoProgress({
    required this.position,
    required this.duration,
    required this.draft,
  });

  bool get hasKnownDuration => duration > Duration.zero;

  bool get canSeek => hasKnownDuration;

  double? get fraction => hasKnownDuration
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : null;

  static const zero = VideoProgress(
    position: .zero,
    duration: .zero,
    draft: false,
  );
}

class VideoGeometry {
  final int generation;

  final double? naturalAspect;

  const VideoGeometry({required this.generation, required this.naturalAspect});

  bool get isPortrait => naturalAspect != null && naturalAspect! <= 1.0;

  static const unknown = VideoGeometry(generation: 0, naturalAspect: null);
}

class VideoPlaybackSettings {
  final double volume;

  final double speed;

  final bool looping;

  const VideoPlaybackSettings({
    required this.volume,
    required this.speed,
    required this.looping,
  });

  VideoPlaybackSettings copyWith({
    double? volume,
    double? speed,
    bool? looping,
  }) => VideoPlaybackSettings(
    volume: volume ?? this.volume,
    speed: speed ?? this.speed,
    looping: looping ?? this.looping,
  );

  static const initial = VideoPlaybackSettings(
    volume: 1.0,
    speed: 1.0,
    looping: false,
  );
}
