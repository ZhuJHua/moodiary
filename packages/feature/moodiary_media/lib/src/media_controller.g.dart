// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaItems)
final mediaItemsProvider = MediaItemsFamily._();

final class MediaItemsProvider
    extends $AsyncNotifierProvider<MediaItems, List<MediaItem>> {
  MediaItemsProvider._({
    required MediaItemsFamily super.from,
    required MediaType super.argument,
  }) : super(
         retry: null,
         name: r'mediaItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaItemsHash();

  @override
  String toString() {
    return r'mediaItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MediaItems create() => MediaItems();

  @override
  bool operator ==(Object other) {
    return other is MediaItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaItemsHash() => r'a8a29012507ce47f47c78b5ac24c33aefbb26c97';

final class MediaItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          MediaItems,
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>,
          MediaType
        > {
  MediaItemsFamily._()
    : super(
        retry: null,
        name: r'mediaItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaItemsProvider call({required MediaType type}) =>
      MediaItemsProvider._(argument: type, from: this);

  @override
  String toString() => r'mediaItemsProvider';
}

abstract class _$MediaItems extends $AsyncNotifier<List<MediaItem>> {
  late final _$args = ref.$arg as MediaType;
  MediaType get type => _$args;

  FutureOr<List<MediaItem>> build({required MediaType type});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(type: _$args));
  }
}

@ProviderFor(audioDuration)
final audioDurationProvider = AudioDurationFamily._();

final class AudioDurationProvider
    extends
        $FunctionalProvider<
          AsyncValue<Duration?>,
          Duration?,
          FutureOr<Duration?>
        >
    with $FutureModifier<Duration?>, $FutureProvider<Duration?> {
  AudioDurationProvider._({
    required AudioDurationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'audioDurationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioDurationHash();

  @override
  String toString() {
    return r'audioDurationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Duration?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Duration?> create(Ref ref) {
    final argument = this.argument as String;
    return audioDuration(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioDurationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioDurationHash() => r'113f724b62004ff3b02d3bc7358648e8f75adf5c';

final class AudioDurationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Duration?>, String> {
  AudioDurationFamily._()
    : super(
        retry: null,
        name: r'audioDurationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AudioDurationProvider call(String fileName) =>
      AudioDurationProvider._(argument: fileName, from: this);

  @override
  String toString() => r'audioDurationProvider';
}
