import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary_logging/moodiary_logging.dart';

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
  final _player = AudioPlayer();

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

  // ExoPlayer seek 后会瞬时回报旧位置，需按目标显示直到流回报追上再跟随
  Duration? _pendingSeek;
  Timer? _seekGuard;

  AudioPlaybackController() {
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

  Future<void> toggle(String path) async {
    try {
      if (activePath.value == path) {
        if (_playing) {
          _emit(playing: false);
          await _player.pause();
        } else if (_completed) {
          _completed = false;
          _emit(playing: true);
          await _player.play(DeviceFileSource(path));
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

  Future<void> seek(double fraction, {Duration? fallbackTotal}) async {
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : (fallbackTotal?.inMilliseconds ?? 0);
    if (totalMs <= 0) return;
    final target = Duration(milliseconds: (fraction * totalMs).round());
    _pendingSeek = target;
    _emit(position: target);
    _seekGuard?.cancel();
    _seekGuard = Timer(
      const Duration(milliseconds: 600),
      () => _pendingSeek = null,
    );
    try {
      await _player.seek(target);
    } catch (_) {}
  }

  Future<void> toggleMute() async {
    final next = !_muted;
    _emit(muted: next);
    await _player.setVolume(next ? 0 : 1);
  }

  void dispose() {
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
