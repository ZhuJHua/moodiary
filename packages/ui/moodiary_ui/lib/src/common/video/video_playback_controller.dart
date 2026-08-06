// 播放器状态机。只 import dart:async 与 foundation（ValueNotifier）—— 无 widget、
// 无 BuildContext、无 video_player，因此可在纯 Dart 单测里手推假端口走完整张转移表。
//
// 分五路 notifier 是为了别让 ~10Hz 的进度把整棵树带着重建：
//   state        低频，生命周期
//   progress     ~10Hz，只有进度条与时间文本订阅
//   geometry     每 generation 一次
//   settings     按需
//   coverVisible 只翻一次
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'video_playback_port.dart';
import 'video_playback_state.dart';

/// 同一时刻只让一个播放器实例出声。平台侧每个实例都各自申请音频焦点，
/// 两个一起播就会互相打断。
class VideoPlaybackArbiter {
  VideoPlaybackArbiter._();

  static MoodiaryVideoPlaybackController? _active;

  static void activate(MoodiaryVideoPlaybackController who) {
    final prev = _active;
    _active = who;
    if (prev != null && prev != who) prev.pause();
  }

  static void release(MoodiaryVideoPlaybackController who) {
    if (_active == who) _active = null;
  }

  @visibleForTesting
  static void resetForTest() => _active = null;
}

class MoodiaryVideoPlaybackController {
  MoodiaryVideoPlaybackController({
    required this.source,
    required this.portFactory,
    double? initialAspect,
    this.autoPlay = true,
  }) {
    // 封面已经给出了显示朝向的比例（缩略图插件按 rotation 归一化过），所以第一帧就能拿到
    // 正确几何，不必等 initialized —— 全屏页因此不会先竖着出现再转过去。
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

  /// 起始 true；首帧确认已上屏后翻 false 并不再回头（除 generation 变化）。
  /// 平台不提供 first-frame-rendered 信号（initialized 只代表 READY，此刻纹理可能还是黑的）。
  final coverVisible = ValueNotifier<bool>(true);

  static const _kInitWatchdog = Duration(seconds: 12);
  static const _kBufferingDebounce = Duration(milliseconds: 250);
  static const _kSeekSettleTolerance = Duration(milliseconds: 400);
  static const _kSeekSettleFallback = Duration(milliseconds: 600);
  static const _kMaxAttempts = 5;

  VideoPlaybackPort? _port;
  StreamSubscription<VideoPortSnapshot>? _sub;

  /// 当前端口。皮肤用它取纹理 widget（配合 geometry.generation 做 key）；
  /// 控制器本身不碰 widget，所以这里只暴露端口而不暴露 Widget。
  VideoPlaybackPort? get port => _port;

  bool _disposed = false;
  int _attempt = 0;
  int _generation = 0;

  /// Ready 与 Paused 在 VideoPlayerValue 上完全同形，只能靠这一位区分。
  bool _hasPlayed = false;

  /// Initializing 期间收到的 play 记在这里，就绪后再派发。
  bool _pendingPlay = false;

  /// completed 的处理是 pause().then(seekTo(duration)) 这条跨帧异步链，中途会看到
  /// isPlaying=false 而 position 还没到末尾。收到上升沿即锁定，忽略随后的噪声。
  bool _completedLatched = false;

  /// 错误会把平台 value 整体擦回 uninitialized，这几份副本供错误页与恢复播放点使用。
  Duration _lastPosition = .zero;
  Duration _lastDuration = .zero;

  /// 已下发 play、等平台回声确认。这期间要忽略快照里的 isPlaying=false ——
  /// 插件那个 100ms 轮询很可能在 play 生效前先报一张「没在播」，跟着它走播放键就会闪一下。
  /// 与 seek 的 draft 同理：命令已发、平台未回声的窗口必须屏蔽。
  bool _awaitingPlayConfirm = false;

  Duration? _seekTarget;
  bool _scrubbing = false;
  Timer? _initWatchdog;
  Timer? _bufferingTimer;
  Timer? _seekFallback;
  Timer? _playConfirmFallback;

  // ────────────────────────────── 命令 ──────────────────────────────

  Future<void> initialize() async {
    if (_disposed) return;
    // 只允许从 Idle（首次）或 Error（retry）进入。
    if (_state is! VideoIdle && _state is! VideoError) return;
    _attempt += 1;
    _pendingPlay = autoPlay;
    _completedLatched = false;
    _setState(VideoInitializing(attempt: _attempt));

    // retry 必须换新实例：同一实例的第二个 initialized 事件会在插件内部 assert。
    _detachPort();
    _generation += 1;
    coverVisible.value = true;
    final port = portFactory(source);
    _port = port;
    _sub = port.snapshots.listen(
      (s) {
        if (_port != port) return; // 旧端口的迟到事件，丢掉
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
      // 不押 Future 单独判定就绪：dispose 与 initialize 竞态时它可能永不完成也不报错，
      // 真正的判据是快照里的 isInitialized（下面 _onSnapshot 会处理）。
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
    // 平台若始终不回声（play 静默失败），1 秒后放开跟随，别永远显示成在播。
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

  /// 手指按下进度条。此后 [updateScrub] 只改 progress，不发 state 通知 ——
  /// 否则一次拖动会发上百次生命周期通知。
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
    // 平台侧只在 isPlaying 时才真正下发（插件刻意规避 iOS 上 setPlaybackSpeed 触发播放），
    // 暂停中改只落在 settings 里，下次 play 由插件自动补发。
    if (_state.acceptsCommands) await _port?.setPlaybackSpeed(v);
  }

  Future<void> setLooping(bool looping) async {
    if (_disposed) return;
    settings.value = settings.value.copyWith(looping: looping);
    if (_state.acceptsCommands) await _port?.setLooping(looping);
  }

  // ────────────────────────────── 快照解读 ──────────────────────────────

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
    if (!s.isInitialized) return; // 就绪前的噪声一律忽略

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

    // Seeking 期间不参与 playing/buffering 的判定：两端 seek 都会让 isBuffering 闪一下。
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
    // 必须先离开 Initializing 再派发 play —— play() 开头会把 Initializing 期间的调用
    // 记成待执行意图然后返回，状态没先落地就会自己把自己挡掉。
    _setState(_hasPlayed ? const VideoPaused() : const VideoReady());
    if (_pendingPlay) {
      _pendingPlay = false;
      play(); // 它自己置 Playing 并开启回声等待窗口
    }
  }

  /// isPlaying 只当意图回声：平台可能在我们没发命令时自行翻转（音频焦点丢失、来电、
  /// 插件自带的生命周期观察者回前台自动续播），状态机必须接受这种外部转移。
  void _applyPlayingFlag(bool isPlaying) {
    if (isPlaying) {
      _clearPlayConfirm();
      if (_state is VideoPlaying) return;
      _hasPlayed = true;
      VideoPlaybackArbiter.activate(this);
      _setState(const VideoPlaying());
    } else {
      // 刚下发 play、还没等到回声 —— 这张「没在播」是滞后的旧快照，不是外部暂停。
      if (_awaitingPlayConfirm) return;
      if (_state is VideoPaused || _state is VideoReady) return;
      _setState(_hasPlayed ? const VideoPaused() : const VideoReady());
    }
  }

  void _maybeMarkCoverGone(VideoPortSnapshot s) {
    if (!coverVisible.value) return;
    // 播放后第一个位置前进的轮询 tick 即视为首帧已上屏。
    if (s.isPlaying && s.position > Duration.zero) coverVisible.value = false;
  }

  // ────────────────────────────── seek ──────────────────────────────

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
    // 已在 Seeking 里就只更新目标，不再发 state 通知：一次「按下—拖动—松手」应当只有
    // begin 与 settle 两次生命周期通知，松手不该额外算一次。
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
    // 兜底：Android 的 seekTo 立即返回但插件那个 100ms 轮询要过一拍才报新位置；
    // iOS 的零容差 seek 可能真的要几百毫秒。两级都不到就强行放开跟随。
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

  // ────────────────────────────── 错误 ──────────────────────────────

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

  // ────────────────────────────── 释放 ──────────────────────────────

  /// 全同步：不 await 任何平台调用，也不 await 退订。
  ///
  /// 迟到事件靠**端口身份**过滤（见 initialize 里的 listen 闭包），不靠 cancel 的时机 ——
  /// 一旦去 await 一个刚 close() 的 broadcast 流的 cancel，就可能永远等不回来。
  void _detachPort() {
    final port = _port;
    final sub = _sub;
    _port = null;
    _sub = null;
    if (port != null) {
      // pause 要立刻发出，取消平台侧那个 100ms 位置轮询。
      port.pause();
      // dispose 可能永久挂起（平台释放失败），绝不 await。
      unawaited(
        port.dispose().catchError((Object e) {
          debugPrint('video port dispose failed: $e');
        }),
      );
    }
    unawaited(sub?.cancel() ?? Future<void>.value());
  }

  /// 严格顺序：置闸 → 写终态 → 让出仲裁 → 停表 → 退订 + 释放端口 → 最后 dispose notifier。
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
