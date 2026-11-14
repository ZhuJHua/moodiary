import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class AudioProgress {
  final Duration position;
  final Duration duration;
  final bool playing;
  final bool muted;

  const AudioProgress({
    required this.position,
    required this.duration,
    required this.playing,
    required this.muted,
  });

  static const zero = AudioProgress(
    position: .zero,
    duration: .zero,
    playing: false,
    muted: false,
  );
}

class AudioPlaybackController {
  final AudioPlayer _player;

  final ValueNotifier<String?> activePath = ValueNotifier(null);

  final ValueNotifier<AudioProgress> progress = ValueNotifier(
    AudioProgress.zero,
  );

  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<void> _completeSub;

  Duration _position = .zero;
  Duration _duration = .zero;
  bool _playing = false;
  bool _muted = false;
  bool _completed = false;
  bool _disposed = false;
  Future<void>? _preparing;

  // ExoPlayer seek 后会瞬时回报旧位置，需按目标显示直到流回报追上再跟随
  Duration? _pendingSeek;
  Timer? _seekGuard;

  AudioPlaybackController() : this._(AudioPlayer());

  @visibleForTesting
  AudioPlaybackController.forTesting(AudioPlayer player) : this._(player);

  AudioPlaybackController._(this._player) {
    _posSub = _player.onPositionChanged.listen((d) {
      final pending = _pendingSeek;
      if (pending != null) {
        if ((d - pending).abs() > const Duration(seconds: 1)) return;
        _pendingSeek = null;
      }
      _emit(position: d);
    });
    // ExoPlayer 在 seek/缓冲边界可能回报 0 或哨兵时长，非正值一律忽略
    _durSub = _player.onDurationChanged.listen((d) {
      if (d > Duration.zero) _emit(duration: d);
    });
    _stateSub = _player.onPlayerStateChanged.listen(
      (s) => _emit(playing: s == .playing),
    );
    _completeSub = _player.onPlayerComplete.listen((_) {
      _completed = true;
      _emit(position: .zero, playing: false);
    });
  }

  void _emit({
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? muted,
  }) {
    if (_disposed) return;
    _position = position ?? _position;
    _duration = duration ?? _duration;
    _playing = playing ?? _playing;
    _muted = muted ?? _muted;
    progress.value = AudioProgress(
      position: _position,
      duration: _duration,
      playing: _playing,
      muted: _muted,
    );
  }

  /// Resolve metadata without starting playback.
  Future<void> prepare(String path) {
    if (_disposed) return Future.value();
    if (activePath.value == path) return _preparing ?? Future.value();
    activePath.value = path;
    _completed = false;
    _position = .zero;
    _duration = .zero;
    _emit(playing: false);
    return _preparing = _prepare(path)
        .catchError((Object error, StackTrace stack) {
          if (!_disposed && activePath.value == path) activePath.value = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  Future<void> _prepare(String path) async {
    // Keep the source after the track ends so paused and end-of-track seeks
    // stay valid; the plugin's default release mode clears it.
    await _player.setReleaseMode(ReleaseMode.stop);
    if (_disposed || activePath.value != path) return;
    await _player.setSource(
      isNetworkMedia(path) ? UrlSource(path) : DeviceFileSource(path),
    );
    final duration = await _player.getDuration();
    if (!_disposed &&
        activePath.value == path &&
        duration != null &&
        duration > Duration.zero) {
      _emit(duration: duration);
    }
  }

  Future<void> toggle(String path) async {
    try {
      if (activePath.value == path) {
        await _preparing;
        if (_disposed) return;
        if (_playing) {
          _emit(playing: false);
          await _player.pause();
        } else if (_completed) {
          _completed = false;
          _emit(playing: true);
          await _player.play(
            isNetworkMedia(path) ? UrlSource(path) : DeviceFileSource(path),
          );
        } else {
          _emit(playing: true);
          await _player.resume();
        }
      } else {
        activePath.value = path;
        _completed = false;
        _pendingSeek = null;
        _position = .zero;
        _duration = .zero;
        _emit(playing: true);
        await _player.play(DeviceFileSource(path));
      }
    } catch (e, s) {
      logger.e('[audio] play failed', error: e, stackTrace: s);
      _emit(playing: false);
    }
  }

  Future<void> pause() async {
    if (_disposed || !_playing) return;
    _emit(playing: false);
    try {
      await _player.pause();
    } catch (e, s) {
      logger.e('[audio] pause failed', error: e, stackTrace: s);
    }
  }

  Future<void> seek(double fraction, {Duration? fallbackTotal}) async {
    if (_disposed) return;
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : (fallbackTotal?.inMilliseconds ?? 0);
    if (totalMs <= 0) return;
    final target = Duration(
      milliseconds: (fraction.clamp(0, 1) * totalMs).round(),
    );
    if (_preparing != null) _completed = target.inMilliseconds >= totalMs;
    _pendingSeek = target;
    _emit(position: target);
    _seekGuard?.cancel();
    _seekGuard = Timer(
      const Duration(milliseconds: 600),
      () => _pendingSeek = null,
    );
    try {
      await _preparing;
      if (_disposed) return;
      await _player.seek(target);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    final next = !_muted;
    _emit(muted: next);
    await _player.setVolume(next ? 0 : 1);
  }

  void dispose() {
    _disposed = true;
    _seekGuard?.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _completeSub.cancel();
    _player.dispose();
    activePath.dispose();
    progress.dispose();
  }
}
