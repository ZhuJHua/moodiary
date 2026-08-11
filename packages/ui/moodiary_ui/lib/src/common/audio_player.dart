import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 播放进度快照（活动音轨用）。
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

/// 单实例音频控制器：全程只持有一个 [AudioPlayer]，同一时刻只播一条；原生解码器在首次
/// 播放时才真正初始化（点了再建）。当前唯一宿主是全屏播放页（MoodiaryAudioPlayerPage），
/// 页面生命周期即控制器生命周期。
class AudioPlaybackController {
  final _player = AudioPlayer();

  /// 当前（或最近）播放的文件路径；null = 空闲。切换即停上一条。
  final ValueNotifier<String?> activePath = ValueNotifier(null);

  /// 活动音轨的进度快照。
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

  // seek 抑制：seek 后 ExoPlayer 会瞬时回报 0/旧位置；先按目标显示，待流回报追上目标再跟随，
  // 否则松手后进度条会闪回 0（看起来像从头重播）。设一个兜底定时器防止永久卡住。
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
    // 播放器在 seek / 缓冲边界会回报 0 或未知哨兵时长（ExoPlayer 对 ADTS 裸流
    // 尤甚），非正值一律忽略——别把已经拿到的总长抹掉，否则刮擦时时长显示会闪没。
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

  /// 播放态一律**乐观更新**：先翻 [progress] 里的 playing 再 await 平台调用——
  /// 等原生状态事件回来才翻图标，会让按钮显得按下去半天没反应。真实事件随后
  /// 收敛（同值幂等）；调用失败在 catch 里回滚为停止态。
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
        // 切换音轨：重置进度并以文件源一步播放（设源+预备+播放，最可靠）。
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

  /// [fallbackTotal]：播放器尚未（或不会）回报时长时用作换算分母——MediaInfo
  /// 表里的已知总长。没有任何时长可用才放弃 seek。
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
