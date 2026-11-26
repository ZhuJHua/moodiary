import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class AudioProgress {
  final Duration position;
  final Duration duration;
  final bool playing;

  const AudioProgress({
    this.position = .zero,
    this.duration = .zero,
    this.playing = false,
  });

  static const zero = AudioProgress();

  AudioProgress copyWith({
    Duration? position,
    Duration? duration,
    bool? playing,
  }) => AudioProgress(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    playing: playing ?? this.playing,
  );
}

class AudioPlaybackController {
  static AudioPlaybackController? _active;

  final String path;
  final AudioPlayer _player;
  final Future<void> Function() _configureSession;
  final Future<void> Function() _releaseSession;

  final ValueNotifier<AudioProgress> progress = ValueNotifier(.zero);

  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration?> _durSub;
  late final StreamSubscription<PlayerException> _errSub;

  Future<void>? _loadFuture;
  int _seekSeq = 0;
  bool _disposed = false;

  AudioPlaybackController(String path)
    : this._(
        path,
        AudioPlayer(useProxyForRequestHeaders: false),
        _configurePlaybackSession,
        _releasePlaybackSession,
      );

  @visibleForTesting
  AudioPlaybackController.forTesting(
    String path,
    AudioPlayer player, {
    Future<void> Function()? configureSession,
    Future<void> Function()? releaseSession,
  }) : this._(
         path,
         player,
         configureSession ?? _noopSession,
         releaseSession ?? _noopSession,
       );

  @visibleForTesting
  static void resetActiveForTest() => _active = null;

  static Future<void> _noopSession() async {}

  static Future<void> _configurePlaybackSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  static Future<void> _releasePlaybackSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  AudioPlaybackController._(
    this.path,
    this._player,
    this._configureSession,
    this._releaseSession,
  ) {
    _stateSub = _player.playerStateStream.listen((state) {
      if (_disposed) return;
      if (state.processingState == .completed) {
        _emit(position: state.playing ? .zero : null, playing: false);
        if (state.playing) unawaited(_resetAfterCompletion());
        return;
      }
      _emit(playing: state.playing && state.processingState != .idle);
    }, onError: (_, _) {});
    _posSub = _player.positionStream.listen((pos) {
      if (_disposed) return;
      final total = progress.value.duration;
      final clamped = total > .zero && pos > total ? total : pos;
      _emit(position: clamped < .zero ? .zero : clamped);
    }, onError: (_, _) {});
    _durSub = _player.durationStream.listen((d) {
      if (_disposed || d == null || d <= .zero) return;
      _emit(duration: d);
    }, onError: (_, _) {});
    _errSub = _player.errorStream.listen((error) {
      if (_disposed) return;
      logger.e('[audio] playback error', error: error);
      _loadFuture = null;
      if (identical(_active, this)) _active = null;
      _emit(playing: false);
      unawaited(_player.pause().catchError((_) {}));
    }, onError: (_, _) {});
  }

  void _emit({Duration? position, Duration? duration, bool? playing}) {
    if (_disposed) return;
    final next = progress.value.copyWith(
      position: position,
      duration: duration,
      playing: playing,
    );
    if (next.position == progress.value.position &&
        next.duration == progress.value.duration &&
        next.playing == progress.value.playing) {
      return;
    }
    progress.value = next;
  }

  Future<void> _resetAfterCompletion() async {
    final seq = _seekSeq;
    try {
      await _player.pause();
      if (_disposed || _player.playing || _seekSeq != seq) return;
      await _player.seek(.zero);
      if (!_disposed && _seekSeq == seq) _emit(position: .zero);
    } catch (_) {}
  }

  /// Resolve metadata without starting playback.
  Future<void> prepare() {
    if (_disposed) return Future.value();
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final duration = isNetworkMedia(path)
          ? await _player.setUrl(path)
          : await _player.setFilePath(path);
      if (!_disposed && duration != null && duration > .zero) {
        _emit(duration: duration);
      }
    } catch (_) {
      _loadFuture = null;
      rethrow;
    }
  }

  Future<void> toggle() async {
    if (_disposed) return;
    if (progress.value.playing) {
      await pause();
      return;
    }
    final previous = _active;
    _active = this;
    if (previous != null && !identical(previous, this)) {
      unawaited(previous.pause());
    }
    try {
      await prepare();
      if (_disposed || !identical(_active, this)) return;
      await _configureSession();
      if (_disposed || !identical(_active, this)) return;
      final total = progress.value.duration;
      if (_player.processingState == .completed ||
          (total > .zero && progress.value.position >= total)) {
        _seekSeq++;
        await _player.seek(.zero);
        if (_disposed || !identical(_active, this)) return;
        _emit(position: .zero);
      }
      _seekSeq++;
      _emit(playing: true);
      unawaited(
        _player.play().catchError((Object e, StackTrace s) {
          if (_disposed || e is PlayerInterruptedException) return;
          logger.e('[audio] play failed', error: e, stackTrace: s);
          _loadFuture = null;
          if (identical(_active, this)) _active = null;
          _emit(playing: false);
          unawaited(_player.pause().catchError((_) {}));
        }),
      );
    } catch (e, s) {
      if (_disposed || e is PlayerInterruptedException) return;
      logger.e('[audio] play failed', error: e, stackTrace: s);
      if (identical(_active, this)) _active = null;
      _emit(playing: false);
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    if (identical(_active, this)) _active = null;
    _emit(playing: false);
    try {
      if (_player.playing) {
        await _player.pause();
      } else if (_player.processingState == .ready ||
          _player.processingState == .buffering) {
        // Clears just_audio's pending interruption-resume flag while keeping position.
        await _player.stop();
      }
    } catch (e, s) {
      logger.e('[audio] pause failed', error: e, stackTrace: s);
    }
  }

  Future<void> seek(double fraction, {Duration? fallbackTotal}) async {
    if (_disposed) return;
    final total = progress.value.duration > .zero
        ? progress.value.duration
        : (fallbackTotal ?? .zero);
    if (total <= .zero) return;
    final target = Duration(
      milliseconds: (fraction.clamp(0, 1) * total.inMilliseconds).round(),
    );
    _seekSeq++;
    _emit(position: target);
    try {
      await prepare();
      if (_disposed) return;
      await _player.seek(target);
    } catch (e, s) {
      if (_disposed || e is PlayerInterruptedException) return;
      logger.e('[audio] seek failed', error: e, stackTrace: s);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final wasActive = identical(_active, this);
    if (wasActive) _active = null;
    _stateSub.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _errSub.cancel();
    unawaited(_player.dispose().catchError((_) {}));
    if (wasActive) unawaited(_releaseSession());
    progress.dispose();
  }
}
