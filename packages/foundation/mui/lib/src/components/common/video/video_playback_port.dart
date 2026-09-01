// 平台播放器的薄端口。状态机只认这个接口，全仓唯一 import video_player 的实现在
// video_player_port_impl.dart —— 于是状态机可以在纯 Dart 单测里用一个 StreamController
// 手推快照走完整张转移表，既不需要 Flutter binding，也不需要给 moodiary_components 加
// video_player_platform_interface 这个 dev 依赖。
//
// 用 Stream + 同步 snapshot getter 而不是 ValueListenable：快照有十个字段，
// 用 ValueNotifier 就得写 == 才能去重，流天然不需要。
import 'dart:async';

import 'video_playback_state.dart';

/// 平台播放器某一时刻的原始快照。字段语义刻意贴近 VideoPlayerValue，
/// 「怎么解读」全部留给状态机。
class VideoPortSnapshot {
  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;

  /// 编码朝向的像素宽高（未就绪时为 0）。**不是**显示朝向 —— 见 rotationDegrees。
  final int width;
  final int height;

  /// 0 / 90 / 180 / 270。Android textureView 后端会给非 0 值，iOS 恒为 0
  /// （它给的 width/height 已是显示朝向）。
  final int rotationDegrees;

  /// 平台错误原文；非 null 即出错，且此时上面各字段可能已被擦回初值。
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

  /// 显示朝向的宽高比；宽高任一为 0 时返回 null。
  /// 90/270 时交换宽高 —— 这正是 VideoPlayerValue.aspectRatio 不做的修正。
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

/// 平台播放器端口。一个实例对应一次播放会话 —— **错误重试必须换新实例**，
/// 同一实例收到第二个 initialized 事件会在插件内部 assert。
abstract class VideoPlaybackPort {
  Stream<VideoPortSnapshot> get snapshots;

  /// 同步读当前快照（状态机在派发命令后需要立刻对账，不能等下一个事件）。
  VideoPortSnapshot get snapshot;

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setPlaybackSpeed(double speed);

  Future<void> setLooping(bool looping);

  /// 可能永久挂起（平台侧释放失败时），调用方**绝不能 await**。
  Future<void> dispose();
}

/// 端口工厂。retry 时状态机用它换新实例；单测里换成假端口。
typedef VideoPlaybackPortFactory = VideoPlaybackPort Function(
  VideoSource source,
);
