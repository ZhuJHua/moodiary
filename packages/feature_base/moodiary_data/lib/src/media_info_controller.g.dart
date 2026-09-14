// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_info_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaInfoController)
final mediaInfoControllerProvider = MediaInfoControllerProvider._();

final class MediaInfoControllerProvider
    extends
        $AsyncNotifierProvider<MediaInfoController, Map<String, MediaInfo>> {
  MediaInfoControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaInfoControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaInfoControllerHash();

  @$internal
  @override
  MediaInfoController create() => MediaInfoController();
}

String _$mediaInfoControllerHash() =>
    r'9a34ce566e2c93530d6afa09b8f6c4f0261b399a';

abstract class _$MediaInfoController
    extends $AsyncNotifier<Map<String, MediaInfo>> {
  FutureOr<Map<String, MediaInfo>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Map<String, MediaInfo>>, Map<String, MediaInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, MediaInfo>>,
                Map<String, MediaInfo>
              >,
              AsyncValue<Map<String, MediaInfo>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(mediaInfoByFileName)
final mediaInfoByFileNameProvider = MediaInfoByFileNameFamily._();

final class MediaInfoByFileNameProvider
    extends $FunctionalProvider<MediaInfo?, MediaInfo?, MediaInfo?>
    with $Provider<MediaInfo?> {
  MediaInfoByFileNameProvider._({
    required MediaInfoByFileNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mediaInfoByFileNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaInfoByFileNameHash();

  @override
  String toString() {
    return r'mediaInfoByFileNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<MediaInfo?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaInfo? create(Ref ref) {
    final argument = this.argument as String;
    return mediaInfoByFileName(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaInfo?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaInfoByFileNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaInfoByFileNameHash() =>
    r'3edfa3c73885fa12626bb2995bb4a6a0b172adb6';

final class MediaInfoByFileNameFamily extends $Family
    with $FunctionalFamilyOverride<MediaInfo?, String> {
  MediaInfoByFileNameFamily._()
    : super(
        retry: null,
        name: r'mediaInfoByFileNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaInfoByFileNameProvider call(String fileName) =>
      MediaInfoByFileNameProvider._(argument: fileName, from: this);

  @override
  String toString() => r'mediaInfoByFileNameProvider';
}
