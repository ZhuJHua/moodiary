import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_providers.g.dart';

typedef VideoSurfaceBuilder = Widget Function(VideoPlaybackPort port);
typedef VideoAmbientPortFactory =
    Map<VideoAmbientChannel, VideoAmbientChannelPort> Function();

@Riverpod(keepAlive: true)
VideoPlaybackPortFactory videoPlayerPortFactory(Ref ref) =>
    throw UnimplementedError(
      'videoPlayerPortFactoryProvider must be overridden',
    );

@Riverpod(keepAlive: true)
VideoSurfaceBuilder videoSurfaceBuilder(Ref ref) =>
    throw UnimplementedError('videoSurfaceBuilderProvider must be overridden');

@Riverpod(keepAlive: true)
VideoAmbientPortFactory videoAmbientPortFactory(Ref ref) =>
    throw UnimplementedError(
      'videoAmbientPortFactoryProvider must be overridden',
    );
