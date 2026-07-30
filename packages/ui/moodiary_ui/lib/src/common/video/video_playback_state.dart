// 播放器核心的值对象。**只允许 import dart:core**（连 dart:ui 都不要 —— 宽高走 int，
// 不用 Size），这样状态机能在纯 Dart 单测里跑，不需要 Flutter binding 也不需要插件桩。
//
// 状态集合刻意区分「平台直接给的」与「我们合成的」：VideoPlayerValue 上「就绪未播」与
// 「暂停在 0」完全同形（isInitialized && !isPlaying && position == 0），只有自记 hasPlayed
// 才能区分，故 Ready / Paused 都是合成态。

/// 播放源。公开 API 只收路径字符串，不泄漏 video_player 的 DataSource。
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

  /// 播放键该画成「暂停」的唯一判据。注意这是**意图回声**而非平台事实：
  /// 缓冲 / 定位期间平台已经不在播了，但用户的意图仍是「播」。
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

  /// 命令闸门的第二道（第一道是控制器自己的 _disposed）。
  bool get acceptsCommands => isInitialized;

  /// UI 是否该显示 spinner。**Seeking 期间必须为 false** —— 两端 seek 都会让
  /// isBuffering 闪一下，跟着画 spinner 就是每拖一下闪一次。
  bool get isBusy => this is VideoInitializing || this is VideoBuffering;
}

class VideoIdle extends VideoPlaybackState {
  const VideoIdle();
}

class VideoInitializing extends VideoPlaybackState {
  /// 1 = 首次；>1 = 第几次 retry。
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
  /// 缓冲结束后回 Playing 还是 Paused。
  final bool resumeIntent;

  const VideoBuffering({required this.resumeIntent});
}

class VideoPaused extends VideoPlaybackState {
  const VideoPaused();
}

class VideoSeeking extends VideoPlaybackState {
  final Duration target;
  final bool resumeIntent;

  /// true = 手指还在条上（scrub）；false = 离散 seek（点轨道 / ±10s / replay）。
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

  /// 平台原文，只用于日志 / 诊断。面向用户的文案由 UI 层经 l10n 决定 ——
  /// 核心层拿不到 BuildContext，也不该依赖 l10n。
  final String message;

  /// 出错前最后已知位置。平台错误会把 value 整体擦回 uninitialized（duration/size/position
  /// 全丢），所以状态机必须自持副本。
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

/// 进度快照 —— 唯一 ~10Hz 变动的通道（插件位置轮询是 Timer.periodic(100ms)）。
/// 只有进度条与时间文本订阅它，别的 widget 一律不许，否则整树每 100ms 重建一次。
class VideoProgress {
  /// UI 必须直接画这个值：scrub / seek 期间它就是**目标位**（draft），平台流里的
  /// position 已被屏蔽。这是「拖动不回弹」的唯一保证。
  final Duration position;
  final Duration duration;

  /// true = 当前显示的是 draft（拖动 / seek 未落定）。
  final bool draft;

  const VideoProgress({
    required this.position,
    required this.duration,
    required this.draft,
  });

  /// duration <= 0 视为未知：Android 的 C.TIME_UNSET 与 iOS 的 indefinite 都会编成
  /// 一个极大负值，而此时 isInitialized 仍为 true。
  bool get hasKnownDuration => duration > Duration.zero;

  bool get canSeek => hasKnownDuration;

  /// 时长未知时返回 null —— 进度条必须**禁用**，而不是画成 0。
  double? get fraction => hasKnownDuration
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : null;

  static const zero = VideoProgress(
    position: Duration.zero,
    duration: Duration.zero,
    draft: false,
  );
}

/// 几何快照 —— 一个 generation 内最多变一次。
///
/// 只给显示朝向的真实比例，**不做容器比例的夹取** —— 那是呈现策略，随皮肤不同
/// （全出血皮肤的容器就是视口，夹取没有意义），交给 UI 层决定。
class VideoGeometry {
  /// 每换一个 port 实例 +1（首次初始化 = 1，每次 retry +1）。
  /// UI 必须用它给纹理子树做 key，否则 retry 后不会真正换纹理。
  final int generation;

  /// 显示朝向的宽高比；未就绪或宽高为 0 时为 null。
  ///
  /// 绝不使用 `VideoPlayerValue.aspectRatio`：它不应用 rotationCorrection，
  /// Android textureView 后端给的是**编码朝向**，带 90/270 旋转标记的竖拍视频会被算成横拍；
  /// 且未就绪时它返回 1.0，无法与正方形视频区分。
  final double? naturalAspect;

  const VideoGeometry({required this.generation, required this.naturalAspect});

  bool get isPortrait => naturalAspect != null && naturalAspect! <= 1.0;

  static const unknown = VideoGeometry(generation: 0, naturalAspect: null);
}

class VideoPlaybackSettings {
  /// 0..1。注意这只是**播放器自身**的音量，不是系统媒体音量。
  final double volume;

  /// 0.25..4。平台侧只在 isPlaying 时才真正下发，暂停中改只记住、下次播放时生效。
  final double speed;

  final bool looping;

  const VideoPlaybackSettings({
    required this.volume,
    required this.speed,
    required this.looping,
  });

  VideoPlaybackSettings copyWith({double? volume, double? speed, bool? looping}) =>
      VideoPlaybackSettings(
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
