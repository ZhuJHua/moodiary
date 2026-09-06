import 'dart:async';
import 'dart:io';

import 'package:mui/mui.dart';
import 'package:video_player/video_player.dart';

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
      width: v.size.width.round(),
      height: v.size.height.round(),
      // rotationDegrees 必须原样带出：value.size/aspectRatio 不应用它，Android textureView 给的是编码朝向
      rotationDegrees: v.rotationCorrection,
      errorMessage: v.hasError
          ? (v.errorDescription ?? 'unknown player error')
          : null,
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
  Future<void> setPlaybackSpeed(double speed) =>
      _controller.setPlaybackSpeed(speed);

  @override
  Future<void> setLooping(bool looping) => _controller.setLooping(looping);

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _controller.removeListener(_emit);
    await _out.close();
    await _controller.dispose();
  }
}

VideoPlaybackPort videoPlayerPortFactory(VideoSource source) =>
    VideoPlayerPluginPort(source);
