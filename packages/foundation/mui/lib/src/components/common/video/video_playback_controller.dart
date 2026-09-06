import 'dart:async';

import 'package:flutter/foundation.dart';

import 'video_playback_port.dart';
import 'video_playback_state.dart';

class VideoPlaybackArbiter {
  VideoPlaybackArbiter._();

  static MVideoPlaybackController? _active;

  static void activate(MVideoPlaybackController who) {
    final prev = _active;
    _active = who;
    if (prev != null && prev != who) prev.pause();
  }

  static void release(MVideoPlaybackController who) {
    if (_active == who) _active = null;
  }

  @visibleForTesting
  static void resetForTest() => _active = null;
}

class MVideoPlaybackController {
  MVideoPlaybackController({
    required this.source,
    required this.portFactory,
    double? initialAspect,
    this.autoPlay = true,
  }) {
    if (initialAspect != null && initialAspect > 0) {
      geometry.value = VideoGeometry(
        generation: 0,
        naturalAspect: initialAspect,
      );
    }
  }

  final VideoSource source;
  final bool autoPlay;
  final VideoPlaybackPortFactory portFactory;

  final state = ValueNotifier<VideoPlaybackState>(const VideoIdle());
  final progress = ValueNotifier<VideoProgress>(.zero);
  final geometry = ValueNotifier<VideoGeometry>(.unknown);
  final settings = ValueNotifier<VideoPlaybackSettings>(.initial);

  final coverVisible = ValueNotifier<bool>(true);

  static const _kInitWatchdog = Duration(seconds: 12);
  static const _kBufferingDebounce = Duration(milliseconds: 250);
  static const _kSeekSettleTolerance = Duration(milliseconds: 400);
  static const _kSeekSettleFallback = Duration(milliseconds: 600);
  static const _kMaxAttempts = 5;

  VideoPlaybackPort? _port;
  StreamSubscription<VideoPortSnapshot>? _sub;

  VideoPlaybackPort? get port => _port;

  bool _disposed = false;
  int _attempt = 0;
  int _generation = 0;

  bool _hasPlayed = false;

  bool _pendingPlay = false;

  bool _completedLatched = false;

  Duration _lastPosition = .zero;
  Duration _lastDuration = .zero;

  bool _awaitingPlayConfirm = false;

  Duration? _seekTarget;
  bool _scrubbing = false;
  Timer? _initWatchdog;
  Timer? _bufferingTimer;
  Timer? _seekFallback;
  Timer? _playConfirmFallback;

  Future<void> initialize() async {
    if (_disposed) return;
    if (_state is! VideoIdle && _state is! VideoError) return;
    _attempt += 1;
    _pendingPlay = autoPlay;
    _completedLatched = false;
    _setState(VideoInitializing(attempt: _attempt));

    _detachPort();
    _generation += 1;
    coverVisible.value = true;
    final port = portFactory(source);
    _port = port;
    _sub = port.snapshots.listen(
      (s) {
        if (_port != port) return;
        _onSnapshot(s);
      },
      onError: (Object e) {
        if (_port != port) return;
        _toError(.playback, '$e');
      },
    );

    _initWatchdog = Timer(_kInitWatchdog, () {
      if (_disposed || _state is! VideoInitializing) return;
      _toError(.initialize, 'initialize timed out');
    });

    try {
      await port.initialize();
      if (!_disposed && _port == port) _onSnapshot(port.snapshot);
    } catch (e) {
      if (!_disposed && _port == port) {
        _toError(.initialize, '$e');
      }
    }
  }

  Future<void> retry() {
    if (_disposed) return .value();
    final err = _state;
    if (err is! VideoError || !err.canRetry) return .value();
    return initialize();
  }

  Future<void> play() async {
    if (_disposed) return;
    if (_state is VideoInitializing) {
      _pendingPlay = true;
      return;
    }
    if (!_state.acceptsCommands) return;
    if (_state is VideoCompleted) {
      await _seek(.zero, scrubbing: false, resumeIntent: true);
    }
    VideoPlaybackArbiter.activate(this);
    _hasPlayed = true;
    _completedLatched = false;
    _armPlayConfirm();
    _setState(const VideoPlaying());
    await _port?.play();
  }

  Future<void> pause() async {
    if (_disposed) return;
    _pendingPlay = false;
    _clearPlayConfirm();
    if (!_state.acceptsCommands) return;
    await _port?.pause();
  }

  void _armPlayConfirm() {
    _awaitingPlayConfirm = true;
    _playConfirmFallback?.cancel();
    _playConfirmFallback = Timer(const Duration(seconds: 1), () {
      _playConfirmFallback = null;
      if (_disposed || !_awaitingPlayConfirm) return;
      _awaitingPlayConfirm = false;
      final s = _port?.snapshot;
      if (s != null && s.isInitialized) _applyPlayingFlag(s.isPlaying);
    });
  }

  void _clearPlayConfirm() {
    _awaitingPlayConfirm = false;
    _playConfirmFallback?.cancel();
    _playConfirmFallback = null;
  }

  Future<void> togglePlay() => _state.isPlayIntent ? pause() : play();

  void beginScrub(Duration target) {
    if (_disposed || !_state.acceptsCommands || !progress.value.canSeek) return;
    _scrubbing = true;
    _applySeekTarget(
      target,
      resumeIntent: _state.isPlayIntent,
      scrubbing: true,
    );
  }

  void updateScrub(Duration target) {
    if (_disposed || !_scrubbing) return;
    _seekTarget = _clampToDuration(target);
    _publishProgress(_lastPosition, draftOverride: true);
  }

  Future<void> endScrub(Duration target) async {
    if (_disposed || !_scrubbing) return;
    _scrubbing = false;
    await _seek(target, scrubbing: false, resumeIntent: _state.isPlayIntent);
  }

  void cancelScrub() {
    if (_disposed || !_scrubbing) return;
    _scrubbing = false;
    _seekTarget = null;
    _seekFallback?.cancel();
    _settleSeek();
  }

  Future<void> seekTo(Duration target) =>
      _seek(target, scrubbing: false, resumeIntent: _state.isPlayIntent);

  Future<void> skip(Duration delta) => seekTo(_lastPositionOrTarget + delta);

  Future<void> replay() async {
    if (_disposed || !_state.acceptsCommands) return;
    await _seek(.zero, scrubbing: false, resumeIntent: true);
    await play();
  }

  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    final v = volume.clamp(0.0, 1.0);
    settings.value = settings.value.copyWith(volume: v);
    if (_state.acceptsCommands) await _port?.setVolume(v);
  }

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    final v = speed.clamp(0.25, 4.0);
    settings.value = settings.value.copyWith(speed: v);
    if (_state.acceptsCommands) await _port?.setPlaybackSpeed(v);
  }

  Future<void> setLooping(bool looping) async {
    if (_disposed) return;
    settings.value = settings.value.copyWith(looping: looping);
    if (_state.acceptsCommands) await _port?.setLooping(looping);
  }

  VideoPlaybackState get _state => state.value;

  void _setState(VideoPlaybackState next) {
    if (_disposed && next is! VideoDisposed) return;
    state.value = next;
  }

  void _onSnapshot(VideoPortSnapshot s) {
    if (_disposed) return;

    final err = s.errorMessage;
    if (err != null) {
      _toError(_state is VideoInitializing ? .initialize : .playback, err);
      return;
    }
    if (!s.isInitialized) return;

    if (s.duration > Duration.zero) _lastDuration = s.duration;
    final aspect = s.displayAspect;
    if (aspect != null && geometry.value.naturalAspect != aspect) {
      geometry.value = VideoGeometry(
        generation: _generation,
        naturalAspect: aspect,
      );
    } else if (geometry.value.generation != _generation) {
      geometry.value = VideoGeometry(
        generation: _generation,
        naturalAspect: geometry.value.naturalAspect,
      );
    }

    if (_state is VideoInitializing) _onInitialized();

    _lastPosition = s.position;
    _maybeSettleSeek(s);
    _publishProgress(s.position);
    _maybeMarkCoverGone(s);

    if (_completedLatched) return;

    if (s.isCompleted && _hasPlayed && !settings.value.looping) {
      _completedLatched = true;
      _seekTarget = null;
      _bufferingTimer?.cancel();
      _setState(const VideoCompleted());
      VideoPlaybackArbiter.release(this);
      return;
    }

    if (_state is VideoSeeking) return;

    if (s.isBuffering) {
      _bufferingTimer ??= Timer(_kBufferingDebounce, () {
        _bufferingTimer = null;
        if (_disposed || _state is VideoSeeking || _state is VideoCompleted) {
          return;
        }
        _setState(VideoBuffering(resumeIntent: _state.isPlayIntent));
      });
    } else {
      _bufferingTimer?.cancel();
      _bufferingTimer = null;
      _applyPlayingFlag(s.isPlaying);
    }
  }

  void _onInitialized() {
    _initWatchdog?.cancel();
    _initWatchdog = null;
    final s = settings.value;
    _port?.setVolume(s.volume);
    _port?.setLooping(s.looping);
    final resumeFrom = _resumeFrom;
    if (resumeFrom > Duration.zero) _port?.seekTo(resumeFrom);
    _resumeFrom = .zero;
    _setState(_hasPlayed ? const VideoPaused() : const VideoReady());
    if (_pendingPlay) {
      _pendingPlay = false;
      play();
    }
  }

  void _applyPlayingFlag(bool isPlaying) {
    if (isPlaying) {
      _clearPlayConfirm();
      if (_state is VideoPlaying) return;
      _hasPlayed = true;
      VideoPlaybackArbiter.activate(this);
      _setState(const VideoPlaying());
    } else {
      if (_awaitingPlayConfirm) return;
      if (_state is VideoPaused || _state is VideoReady) return;
      _setState(_hasPlayed ? const VideoPaused() : const VideoReady());
    }
  }

  void _maybeMarkCoverGone(VideoPortSnapshot s) {
    if (!coverVisible.value) return;
    if (s.isPlaying && s.position > Duration.zero) coverVisible.value = false;
  }

  Duration get _lastPositionOrTarget => _seekTarget ?? _lastPosition;

  Duration _clampToDuration(Duration d) {
    if (_lastDuration <= Duration.zero) {
      return d < Duration.zero ? .zero : d;
    }
    if (d < Duration.zero) return .zero;
    return d > _lastDuration ? _lastDuration : d;
  }

  void _applySeekTarget(
    Duration target, {
    required bool resumeIntent,
    required bool scrubbing,
  }) {
    _seekTarget = _clampToDuration(target);
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    if (_state is! VideoSeeking) {
      _setState(
        VideoSeeking(
          target: _seekTarget!,
          resumeIntent: resumeIntent,
          scrubbing: scrubbing,
        ),
      );
    }
    _publishProgress(_lastPosition, draftOverride: true);
  }

  Future<void> _seek(
    Duration target, {
    required bool scrubbing,
    required bool resumeIntent,
  }) async {
    if (_disposed || !_state.acceptsCommands || !progress.value.canSeek) return;
    _completedLatched = false;
    _applySeekTarget(target, resumeIntent: resumeIntent, scrubbing: scrubbing);
    final aim = _seekTarget!;

    _seekFallback?.cancel();
    _seekFallback = Timer(_kSeekSettleFallback, () {
      if (_disposed || _scrubbing) return;
      _settleSeek();
    });

    await _port?.seekTo(aim);
    if (_disposed) return;
    _maybeSettleSeek(_port?.snapshot ?? .empty);
  }

  void _maybeSettleSeek(VideoPortSnapshot s) {
    final aim = _seekTarget;
    if (aim == null || _scrubbing) return;
    final diff = (s.position - aim).abs();
    if (diff <= _kSeekSettleTolerance) _settleSeek();
  }

  void _settleSeek() {
    _seekFallback?.cancel();
    _seekFallback = null;
    final wasSeeking = _state;
    _seekTarget = null;
    if (wasSeeking is! VideoSeeking) {
      _publishProgress(_lastPosition);
      return;
    }
    if (wasSeeking.resumeIntent) {
      _setState(const VideoPlaying());
    } else {
      _setState(_hasPlayed ? const VideoPaused() : const VideoReady());
    }
    _publishProgress(_lastPosition);
  }

  void _publishProgress(Duration position, {bool? draftOverride}) {
    final draft = draftOverride ?? (_seekTarget != null);
    progress.value = VideoProgress(
      position: draft ? (_seekTarget ?? position) : position,
      duration: _lastDuration,
      draft: draft,
    );
  }

  Duration _resumeFrom = .zero;

  void _toError(VideoErrorKind kind, String message) {
    if (_disposed) return;
    _initWatchdog?.cancel();
    _initWatchdog = null;
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    _seekFallback?.cancel();
    _seekFallback = null;
    _seekTarget = null;
    _scrubbing = false;
    _clearPlayConfirm();
    _resumeFrom = _lastPosition;
    VideoPlaybackArbiter.release(this);
    _setState(
      VideoError(
        kind: kind,
        message: message,
        resumeFrom: _lastPosition,
        canRetry: _attempt < _kMaxAttempts,
        attempt: _attempt,
      ),
    );
  }

  void _detachPort() {
    final port = _port;
    final sub = _sub;
    _port = null;
    _sub = null;
    if (port != null) {
      port.pause();
      unawaited(
        port.dispose().catchError((Object e) {
          debugPrint('video port dispose failed: $e');
        }),
      );
    }
    unawaited(sub?.cancel() ?? Future<void>.value());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    state.value = const VideoDisposed();
    VideoPlaybackArbiter.release(this);
    _initWatchdog?.cancel();
    _bufferingTimer?.cancel();
    _seekFallback?.cancel();
    _playConfirmFallback?.cancel();
    _detachPort();
    state.dispose();
    progress.dispose();
    geometry.dispose();
    settings.dispose();
    coverVisible.dispose();
  }
}
