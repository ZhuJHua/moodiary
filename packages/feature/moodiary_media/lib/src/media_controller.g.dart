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
    extends $AsyncNotifierProvider<MediaItems, PagedList<MediaItem>> {
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

String _$mediaItemsHash() => r'f0bc260ef36dc5055d23f918dec87c8af1c939a1';

final class MediaItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          MediaItems,
          AsyncValue<PagedList<MediaItem>>,
          PagedList<MediaItem>,
          FutureOr<PagedList<MediaItem>>,
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

abstract class _$MediaItems extends $AsyncNotifier<PagedList<MediaItem>> {
  late final _$args = ref.$arg as MediaType;
  MediaType get type => _$args;

  FutureOr<PagedList<MediaItem>> build({required MediaType type});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PagedList<MediaItem>>, PagedList<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PagedList<MediaItem>>,
                PagedList<MediaItem>
              >,
              AsyncValue<PagedList<MediaItem>>,
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

String _$audioDurationHash() => r'a37c40c814c5c53ad2094cfa205a8df4d22e3c29';

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

@ProviderFor(attachmentSize)
final attachmentSizeProvider = AttachmentSizeFamily._();

final class AttachmentSizeProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  AttachmentSizeProvider._({
    required AttachmentSizeFamily super.from,
    required (String, {bool audio}) super.argument,
  }) : super(
         retry: null,
         name: r'attachmentSizeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$attachmentSizeHash();

  @override
  String toString() {
    return r'attachmentSizeProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as (String, {bool audio});
    return attachmentSize(ref, argument.$1, audio: argument.audio);
  }

  @override
  bool operator ==(Object other) {
    return other is AttachmentSizeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$attachmentSizeHash() => r'411ddb436bb08a90b3285449b66cf5a7a795fdaf';

final class AttachmentSizeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, (String, {bool audio})> {
  AttachmentSizeFamily._()
    : super(
        retry: null,
        name: r'attachmentSizeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AttachmentSizeProvider call(String fileName, {bool audio = false}) =>
      AttachmentSizeProvider._(argument: (fileName, audio: audio), from: this);

  @override
  String toString() => r'attachmentSizeProvider';
}
