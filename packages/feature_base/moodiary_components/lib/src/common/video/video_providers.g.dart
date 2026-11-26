// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoPlayerPortFactory)
final videoPlayerPortFactoryProvider = VideoPlayerPortFactoryProvider._();

final class VideoPlayerPortFactoryProvider
    extends
        $FunctionalProvider<
          VideoPlaybackPortFactory,
          VideoPlaybackPortFactory,
          VideoPlaybackPortFactory
        >
    with $Provider<VideoPlaybackPortFactory> {
  VideoPlayerPortFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoPlayerPortFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoPlayerPortFactoryHash();

  @$internal
  @override
  $ProviderElement<VideoPlaybackPortFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoPlaybackPortFactory create(Ref ref) {
    return videoPlayerPortFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoPlaybackPortFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoPlaybackPortFactory>(value),
    );
  }
}

String _$videoPlayerPortFactoryHash() =>
    r'c8ada500e8b9ce22f034740121acd200fefffbe4';

@ProviderFor(videoSurfaceBuilder)
final videoSurfaceBuilderProvider = VideoSurfaceBuilderProvider._();

final class VideoSurfaceBuilderProvider
    extends
        $FunctionalProvider<
          VideoSurfaceBuilder,
          VideoSurfaceBuilder,
          VideoSurfaceBuilder
        >
    with $Provider<VideoSurfaceBuilder> {
  VideoSurfaceBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoSurfaceBuilderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoSurfaceBuilderHash();

  @$internal
  @override
  $ProviderElement<VideoSurfaceBuilder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoSurfaceBuilder create(Ref ref) {
    return videoSurfaceBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoSurfaceBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoSurfaceBuilder>(value),
    );
  }
}

String _$videoSurfaceBuilderHash() =>
    r'65b16ff5eade6e6bf78e6fded70a2206d0e0ae76';

@ProviderFor(videoAmbientPortFactory)
final videoAmbientPortFactoryProvider = VideoAmbientPortFactoryProvider._();

final class VideoAmbientPortFactoryProvider
    extends
        $FunctionalProvider<
          VideoAmbientPortFactory,
          VideoAmbientPortFactory,
          VideoAmbientPortFactory
        >
    with $Provider<VideoAmbientPortFactory> {
  VideoAmbientPortFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoAmbientPortFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoAmbientPortFactoryHash();

  @$internal
  @override
  $ProviderElement<VideoAmbientPortFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoAmbientPortFactory create(Ref ref) {
    return videoAmbientPortFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoAmbientPortFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoAmbientPortFactory>(value),
    );
  }
}

String _$videoAmbientPortFactoryHash() =>
    r'3e7b31ad98b3d78667a0104aa03223c68bb32e69';
