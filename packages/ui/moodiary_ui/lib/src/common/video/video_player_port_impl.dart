// 全仓**唯一** import video_player 的文件。状态机只认 VideoPlaybackPort，于是：
//  · 纯 Dart 单测里换成假端口即可，不必给 moodiary_ui 加 video_player_platform_interface 的 dev 依赖
//  · 将来换播放引擎（media_kit 之类）只动这一个文件
//
// 这里刻意**不**做任何状态解读 —— isPlaying 是意图回声还是事实、isBuffering 抖不抖、
// Ready 与 Paused 怎么区分，全部是状态机的事。本文件只负责把 VideoPlayerValue 原样搬成快照。
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'video_playback_port.dart';
import 'video_playback_state.dart';

class VideoPlayerPluginPort implements VideoPlaybackPort {
  VideoPlayerPluginPort(this.source) {
    _controller = switch (source) {
      VideoFileSource(:final path) => VideoPlayerController.file(File(path)),
    };
    _controller.addListener(_emit);
  }

  final VideoSource source;
  late final VideoPlayerController _controller;
  final _out = StreamController<VideoPortSnapshot>.broadcast();

  bool _closed = false;

  /// 纹理 widget。皮肤拿它挂到树上，并用 geometry.generation 做 key。
  Widget buildSurface() => VideoPlayer(_controller);

  void _emit() {
    if (_closed) return;
    _out.add(snapshot);
  }

  @override
  Stream<VideoPortSnapshot> get snapshots => _out.stream;

  @override
  VideoPortSnapshot get snapshot {
    final v = _controller.value;
    return VideoPortSnapshot(
      isInitialized: v.isInitialized,
      isPlaying: v.isPlaying,
      isBuffering: v.isBuffering,
      isCompleted: v.isCompleted,
      position: v.position,
      duration: v.duration,
      // size 在未就绪时是 Size.zero；转成 int 交给状态机判 >0。
      width: v.size.width.round(),
      height: v.size.height.round(),
      // 关键：把旋转标记原样带出去。value.size / value.aspectRatio 都**不**应用它，
      // Android textureView 后端给的是编码朝向，竖拍视频靠这个字段才能算对显示比例。
      rotationDegrees: v.rotationCorrection,
      errorMessage: v.hasError ? (v.errorDescription ?? 'unknown player error') : null,
    );
  }

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Future<void> setPlaybackSpeed(double speed) => _controller.setPlaybackSpeed(speed);

  @override
  Future<void> setLooping(bool looping) => _controller.setLooping(looping);

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _controller.removeListener(_emit);
    await _out.close();
    // 插件的 dispose 在平台释放失败时可能永不完成 —— 上层用 unawaited 调本方法，
    // 所以这里 await 它是安全的（挂住的只是这个已被丢弃的 Future）。
    await _controller.dispose();
  }
}

/// 默认端口工厂。状态机 retry 时用它换新实例。
VideoPlaybackPort videoPlayerPortFactory(VideoSource source) => VideoPlayerPluginPort(source);
